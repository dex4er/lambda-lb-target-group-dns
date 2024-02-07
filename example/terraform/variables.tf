variable "assume_role" {
  type        = string
  description = "Assume role for this Terraform workspace."
  default     = null
}

variable "aws_profile" {
  type        = string
  description = "AWS profile used for this Terraform workspace."
  default     = null
}

variable "aws_region" {
  type        = string
  description = "AWS region used for this Terraform workspace."
  default     = "us-east-1"
}

variable "default_tags" {
  type        = map(string)
  description = "Set of the default tags."
  default     = {}
}

variable "name" {
  type        = string
  description = "Name of the lambda function and other resources related to it."
  default     = "lambda-lb-target-group-dns"
}

variable "domain_name" {
  type        = string
  description = "Domain name of the target."
}

variable "target_port" {
  type        = number
  description = "TCP port number for target group"
  default     = 80
}

variable "vpc_id" {
  type        = string
  description = "VPC id"
  default     = null
}

variable "vpc_subnet_ids" {
  type        = list(string)
  description = "List of subnet ids when Lambda Function should run in the VPC."
  default     = []
}
