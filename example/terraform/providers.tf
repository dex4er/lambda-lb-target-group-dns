provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile

  assume_role {
    role_arn = var.assume_role
  }

  default_tags {
    tags = var.default_tags
  }
}
