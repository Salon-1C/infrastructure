terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }

  # Remote state in S3 + DynamoDB lock table.
  # Create the bucket and table before the first `terraform init`.
  backend "s3" {
    bucket         = "blume-tfstate"
    key            = "blume/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "blume-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project
      ManagedBy   = "terraform"
      Environment = var.environment
    }
  }
}
