terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Remote state – use an S3 backend in a real project
  # backend "s3" {
  #   bucket  = "my-tfstate-bucket"
  #   key     = "checkov-demo/terraform.tfstate"
  #   region  = "eu-west-1"
  #   encrypt = true
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "checkov-demo"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
