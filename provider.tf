terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.37.0" # aws provider version
    }
  }
}

provider "aws" {
  region = "us-east-1"
}