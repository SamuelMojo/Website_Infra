terraform {
  required_version = ">= 1.5.0"

  # Remote state + locking. Created by ./bootstrap.
  backend "s3" {
    bucket         = "samuelojo-tfstate-094813111563"
    key            = "portfolio/terraform.tfstate"
    region         = "eu-west-2"
    dynamodb_table = "samuelojo-tfstate-lock"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = "eu-west-2"
}

# CloudFront certificates and Route 53 health-check metrics live in us-east-1
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

provider "azurerm" {
  skip_provider_registration = true
  features {}
}
