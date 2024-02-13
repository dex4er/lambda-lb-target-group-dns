module "security_group_lambda" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "${var.name}-lambda"
  description = "Security Group for Lambda Egress"

  vpc_id = var.vpc_id

  egress_cidr_blocks      = ["0.0.0.0/0"]
  egress_ipv6_cidr_blocks = []

  egress_rules = ["https-443-tcp"]
}

module "lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.0"

  function_name = var.name
  description   = "AWS Lambda which registers IP addresses to the LB Target Group based on DNS record"
  runtime       = "provided.al2023"
  handler       = "bootstrap"
  architectures = ["arm64"]

  timeout = 120

  vpc_subnet_ids                = var.vpc_subnet_ids
  vpc_security_group_ids        = [module.security_group_lambda.security_group_id]
  attach_cloudwatch_logs_policy = true
  attach_network_policy         = true

  role_name          = "${var.name}-lambda"
  attach_policy_json = true
  policy_json        = data.aws_iam_policy_document.lambda_function.json

  create_package         = false
  package_type           = "Zip"
  local_existing_package = "../../dist/lambda-lb-target-group-dns-linux-arm64.zip"

  tags = {
    Name = var.name
  }
}

resource "aws_lb_target_group" "this" {
  name        = var.name
  port        = var.target_port
  protocol    = "TLS"
  target_type = "ip"
  vpc_id      = var.vpc_id
}

data "aws_iam_policy_document" "lambda_function" {
  statement {
    sid       = ""
    effect    = "Allow"
    resources = ["*"]

    actions = [
      "elasticloadbalancing:DescribeTargetGroups",
      "elasticloadbalancing:DescribeTargetHealth",
    ]
  }

  statement {
    sid       = ""
    effect    = "Allow"
    resources = [aws_lb_target_group.this.arn]

    actions = [
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:RegisterTargets",
    ]
  }
}

module "eventbridge" {
  source  = "terraform-aws-modules/eventbridge/aws"
  version = "~> 3.2"

  bus_name = var.name

  role_name            = "${var.name}-eventbridge"
  attach_lambda_policy = true
  lambda_target_arns   = [module.lambda_function.lambda_function_arn]

  schedules = {
    (var.name) = {
      description         = "Trigger for a Lambda"
      schedule_expression = "rate(1 minute)"
      timezone            = "Europe/Berlin"
      arn                 = module.lambda_function.lambda_function_arn
      input = jsonencode(
        {
          targetGroupArn = aws_lb_target_group.this.arn,
          domainName     = var.domain_name,
          targetPort     = var.target_port
        }
      )
    }
  }
}
