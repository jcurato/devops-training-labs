terraform {
  required_version = ">= 1.9"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
  }
}

# No backend block on purpose. Local state is the right default for a lab
# you run against your own account and tear down when you're done — a
# remote backend (S3 + DynamoDB lock) is a real concept, but it's a Week 8
# "how a team runs this for real" topic, not a Week 1 one.
provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}
