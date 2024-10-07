from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from mypy_boto3_elbv2 import ElasticLoadBalancingv2Client
    from mypy_boto3_elbv2.literals import TargetGroupIpAddressTypeEnumType
    from mypy_boto3_elbv2.type_defs import TargetGroupTypeDef
else:
    ElasticLoadBalancingv2Client = object
    TargetGroupIpAddressTypeEnumType = object
    TargetGroupTypeDef = object

from typing import Any, Dict

import boto3
import dns.resolver
from aws_lambda_powertools.logging.logger import Logger
from aws_lambda_powertools.utilities.data_classes.common import DictWrapper
from aws_lambda_powertools.utilities.typing import LambdaContext
from dns.rdatatype import RdataType


class MyEvent(DictWrapper):
    @property
    def target_group_arn(self) -> str:
        return self["targetGroupArn"]

    @property
    def domain_name(self) -> str:
        return self["domainName"]

    @property
    def target_port(self) -> int:
        return int(str(self.get("targetPort", 0)))

    @property
    def dry_run(self) -> bool:
        return bool(self.get("dryRun", False))


def lookup_ip(domain_name: str, rdtype: RdataType) -> list[str]:
    try:
        resolver = dns.resolver.Resolver()
        answer = resolver.resolve(domain_name, rdtype)
        return [rdata.to_text() for rdata in answer]
    except dns.resolver.NXDOMAIN:
        logger.warning(f"Domain {domain_name} not found")
        return []
    except Exception as e:
        raise e


def get_target_group(
    elbv2: ElasticLoadBalancingv2Client, target_group_arn: str
) -> TargetGroupTypeDef:
    response = elbv2.describe_target_groups(TargetGroupArns=[target_group_arn])
    target_groups = response.get("TargetGroups", [])
    if not target_groups:
        raise ValueError(f"Target Group {target_group_arn} not found")
    return target_groups[0]


def get_target_group_ips(
    elbv2: ElasticLoadBalancingv2Client, target_group_arn: str
) -> list[str]:
    response = elbv2.describe_target_health(TargetGroupArn=target_group_arn)
    ip_addresses = [
        th["Target"]["Id"]
        for th in response["TargetHealthDescriptions"]
        if "Target" in th and "Id" in th["Target"]
    ]
    return ip_addresses


def register_target(
    elbv2: ElasticLoadBalancingv2Client,
    target_group_arn: str,
    target_ip: str,
    target_port: int,
) -> None:
    elbv2.register_targets(
        TargetGroupArn=target_group_arn,
        Targets=[{"Id": target_ip, "Port": target_port}],
    )


ip_address_type_to_rdtype: dict[TargetGroupIpAddressTypeEnumType, RdataType] = {
    "ipv4": RdataType.A,
    "ipv6": RdataType.AAAA,
}


logger = Logger(level="DEBUG")


@logger.inject_lambda_context(log_event=True)
def lambda_handler(event: Dict[str, Any], _context: LambdaContext) -> None:
    myevent = MyEvent(event)

    if not myevent.target_group_arn:
        raise ValueError("Missing target_group_arn in the event")
    if not myevent.domain_name:
        raise ValueError("Missing domain_name in the event")

    elbv2 = boto3.client(service_name="elbv2")

    tg = get_target_group(elbv2, myevent.target_group_arn)
    if tg.get("TargetType") != "ip":
        raise ValueError("Target Group type must be ip")

    if myevent.target_port == 0:
        target_port = tg.get("Port", 0)
    else:
        target_port = myevent.target_port

    ip_address_type = tg.get("IpAddressType")
    if not ip_address_type:
        raise ValueError("Incorrect IP address type")
    dns_ip_addresses = lookup_ip(
        myevent.domain_name, ip_address_type_to_rdtype[ip_address_type]
    )
    logger.info(f"Domain {myevent.domain_name} resolves to {dns_ip_addresses}")

    tg_ip_addresses = get_target_group_ips(elbv2, myevent.target_group_arn)
    logger.info(
        f"Target Group {myevent.target_group_arn} has registered {tg_ip_addresses}"
    )

    all_dns_ip_addresses = {ip: True for ip in dns_ip_addresses}
    all_tg_ip_addresses = {ip: True for ip in tg_ip_addresses}

    for ip in dns_ip_addresses:
        if ip not in all_tg_ip_addresses:
            logger.info(
                f"Adding {ip}:{target_port} to Target Group {myevent.target_group_arn}"
            )
            if not myevent.dry_run:
                elbv2.register_targets(
                    TargetGroupArn=myevent.target_group_arn,
                    Targets=[{"Id": ip, "Port": target_port}],
                )

    for ip in tg_ip_addresses:
        if ip not in all_dns_ip_addresses:
            logger.info(
                f"Removing {ip}:{target_port} from Target Group {myevent.target_group_arn}"
            )
            if not myevent.dry_run:
                elbv2.deregister_targets(
                    TargetGroupArn=myevent.target_group_arn,
                    Targets=[{"Id": ip, "Port": target_port}],
                )
