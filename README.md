# lambda-lb-target-group-dns

[![GitHub](https://img.shields.io/github/v/tag/dex4er/lambda-lb-target-group-dns?label=GitHub)](https://github.com/dex4er/lambda-lb-target-group-dns)
[![Snapshot](https://github.com/dex4er/lambda-lb-target-group-dns/actions/workflows/snapshot.yaml/badge.svg)](https://github.com/dex4er/lambda-lb-target-group-dns/actions/workflows/snapshot.yaml)
[![Release](https://github.com/dex4er/lambda-lb-target-group-dns/actions/workflows/release.yaml/badge.svg)](https://github.com/dex4er/lambda-lb-target-group-dns/actions/workflows/release.yaml)
[![Trunk Check](https://github.com/dex4er/lambda-lb-target-group-dns/actions/workflows/trunk.yaml/badge.svg)](https://github.com/dex4er/lambda-lb-target-group-dns/actions/workflows/trunk.yaml)
[![Docker Image Version](https://img.shields.io/docker/v/dex4er/lambda-lb-target-group-dns?label=Docker&logo=docker&sort=semver)](https://hub.docker.com/r/dex4er/lambda-lb-target-group-dns)
[![Amazon ECR Image Version](https://img.shields.io/docker/v/dex4er/lambda-lb-target-group-dns?label=Amazon%20ECR&logo=Amazon+AWS&sort=semver)](https://gallery.ecr.aws/dex4er/lambda-lb-target-group-dns)

AWS Lambda which registers IP addresses to the LB Target Group based on DNS
record.

## Usage

Copy the container to your private ECR and use it as the container image or
copy ZIP distribution and use it with an Amazon Linux 2023 runtime.

Lambda accepts parameters:

```json
{
  "targetGroupArn": "arn:aws:elasticloadbalancing:REGION:ACCOUNTID:targetgroup/TARGETGROUP/NNN",
  "domainName": "XXX.gr7.REGION.eks.amazonaws.com",
  "targetPort": 0
}
```

Lambda returns the status:

```json
{
  "status": "OK"
}
```

You can test it as a standalone tool as:

```sh
lambda-lb-target-group-dns -target-group-arn XXX -domain-name XXX -target-port NNN
```

### Container image

Copy the container to your private ECR:

From DockerHub:

```sh
docker pull dex4er/lambda-lb-target-group-dns:TAG
docker tag dex4er/lambda-lb-target-group-dns:TAG ACCOUNTID.dkr.ecr.REGION.amazonaws.com/dex4er/lambda-lb-target-group-dns:TAG
docker push ACCOUNTID.dkr.ecr.REGION.amazonaws.com/dex4er/lambda-lb-target-group-dns:TAG
```

or from Amazon ECR Public:

```sh
docker pull public.ecr.aws/dex4er/lambda-lb-target-group-dns:TAG
docker tag public.ecr.aws/dex4er/lambda-lb-target-group-dns:TAG ACCOUNTID.dkr.ecr.REGION.amazonaws.com/dex4er/lambda-lb-target-group-dns:TAG
docker push ACCOUNTID.dkr.ecr.REGION.amazonaws.com/dex4er/lambda-lb-target-group-dns:TAG
```

Supported tags:

- vX.Y.Z-linux-amd64
- vX.Y.Z-linux-arm64
- vX.Y.Z
- vX.Y
- vX
- latest

## IAM

This lambda function needs the following permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticloadbalancing:DescribeTargetHealth",
        "elasticloadbalancing:RegisterTargets"
      ],
      "Resource": "*"
    }
  ]
}
```

## License

The MIT License (MIT)

Copyright (c) 2024 Piotr Roszatycki <piotr.roszatycki@gmail.com>
