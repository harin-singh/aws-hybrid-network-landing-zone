# Root configuration for Terraform testing
# This file enables `terraform test` to run with mock providers

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    # Declared for `terraform test` mock_provider "aws"; root has no AWS resources.
    # tflint-ignore: terraform_unused_required_providers
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}
