terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"

  # Usage: https://developer.hashicorp.com/terraform/language/settings/backends/s3
  backend "s3" {
    bucket         = "gonz-s3"
    key            = "gonz-s3/terraform/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "gonz-terraform-lock"
  }
}
