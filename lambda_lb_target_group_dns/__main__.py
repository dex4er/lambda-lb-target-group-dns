"""
To test the lambda in CLI run in a pyproject directory:

```sh
poetry install
poetry run python -m lambda_lb_target_group_dns
```

The main funtion is removed from the package ZIP file.
"""

from typing import Any, Dict

import boto3
import typed_argparse
from aws_lambda_powertools.utilities.typing import LambdaContext
from botocore.exceptions import NoCredentialsError

from .lambda_function import lambda_handler


class Args(typed_argparse.TypedArgs):
    target_group_arn: str = typed_argparse.arg(
        positional=True, help="ARN of the Target Group"
    )
    domain_name: str = typed_argparse.arg(
        positional=True, help="Domain name for DNS lookup"
    )
    target_port: int = typed_argparse.arg(default=0, help="Target port number")
    dry_run: bool = typed_argparse.arg(
        default=False, help="Perform a dry run without changing anything"
    )


def runner(args: Args) -> None:
    try:
        sts = boto3.client("sts")
        sts.get_caller_identity().get("Account")
    except NoCredentialsError as exc:
        raise SystemExit(
            'Unable to locate credentials. You can configure credentials by running "aws configure".'
        ) from exc

    event: Dict[str, Any] = {
        "targetGroupArn": args.target_group_arn,
        "domainName": args.domain_name,
        "targetPort": args.target_port,
        "dryRun": args.dry_run,
    }

    context = LambdaContext()
    vars(context).update(
        {
            "_function_name": __name__,
            "_memory_limit_in_mb": 0,
            "_invoked_function_arn": "arn:local",
            "_aws_request_id": "0",
        }
    )

    lambda_handler(event, context)


def main() -> None:
    typed_argparse.Parser(Args).bind(runner).run()


if __name__ == "__main__":
    main()
