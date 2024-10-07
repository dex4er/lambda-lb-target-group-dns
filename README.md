# lambda-lb-target-group-dns

[![GitHub](https://img.shields.io/github/v/tag/dex4er/lambda-lb-target-group-dns?label=GitHub)](https://github.com/dex4er/lambda-lb-target-group-dns)
[![Snapshot](https://github.com/dex4er/lambda-lb-target-group-dns/actions/workflows/snapshot.yaml/badge.svg)](https://github.com/dex4er/lambda-lb-target-group-dns/actions/workflows/snapshot.yaml)
[![Release](https://github.com/dex4er/lambda-lb-target-group-dns/actions/workflows/release.yaml/badge.svg)](https://github.com/dex4er/lambda-lb-target-group-dns/actions/workflows/release.yaml)
[![Trunk Check](https://github.com/dex4er/lambda-lb-target-group-dns/actions/workflows/trunk.yaml/badge.svg)](https://github.com/dex4er/lambda-lb-target-group-dns/actions/workflows/trunk.yaml)

AWS Lambda which registers IP addresses to the LB Target Group based on DNS
record.

## Usage

Build the package ZIP file with command:

```sh
python build-lambda.py
```

This command uses `zip` command to pack the files.

This lambda uses layer for `aws-lambda-powertools` then this dependency is in
`dev` group rather than run-time dependencies.

Lambda is installed using `local_existing_package` so directly from ZIP files
to prevent constant drift in TFE where `local` provider does not have
persistency.

Required arguments:

```terraform
module "lambda_for_notifications" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.0"

  runtime       = "python3.12"
  handler       = "lambda_lb_target_group_dns.lambda_function.lambda_handler"
  architectures = ["arm64"] # or ["x86_64"]

  publish = true

  layers = [
    "arn:aws:lambda:${var.region}:017000801446:layer:AWSLambdaPowertoolsPythonV3-python312-arm64:1"
  ]

  create_package         = false
  local_existing_package = "${path.module}/package.zip"
}
```

Lambda accepts parameters:

```json
{
  "targetGroupArn": "arn:aws:elasticloadbalancing:REGION:ACCOUNTID:targetgroup/TARGETGROUP/NNN",
  "domainName": "XXX.gr7.REGION.eks.amazonaws.com",
  "targetPort": 0,
  "dryRun": true
}
```

You can test it as a standalone tool as:

```sh
poetry install
poetry run python -m lambda_lb_target_group_dns TARGET DOMAIN --target-port NNN --dry-run
```

## IAM

This lambda function needs the following permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:DescribeTargetGroups",
        "elasticloadbalancing:DescribeTargetHealth"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "elasticloadbalancing:DeregisterTargets",
        "elasticloadbalancing:RegisterTargets"
      ],
      "Resource": "arn:aws:elasticloadbalancing:REGION:ACCOUNTID:targetgroup/NAME/NNN"
    }
  ]
}
```

## Example

See [example/terraform](example/terraform) directory for an example how to
use this lambda function.

## License

The MIT License (MIT)

Copyright (c) 2024 Piotr Roszatycki <piotr.roszatycki@gmail.com>
