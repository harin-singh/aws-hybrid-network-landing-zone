# Spoke VPC: no IGW, locked default SG, optional TGW attachment.

mock_provider "aws" {}

variables {
  name                 = "test-spoke"
  environment          = "prod"
  region               = "us-east-1"
  cidr_block           = "10.10.0.0/24"
  az_count             = 2
  availability_zones   = ["us-east-1a", "us-east-1b"]
  enable_ssm_endpoints = false
  enable_flow_logs     = false
  tags = {
    Environment = "test"
  }
}

run "private_only_vpc" {
  command = plan
  module {
    source = "./modules/spoke-vpc"
  }

  assert {
    condition     = aws_vpc.this.cidr_block == "10.10.0.0/24"
    error_message = "VPC CIDR must match the input"
  }
  assert {
    condition     = length(aws_subnet.private) == 2 && length(aws_subnet.tgw_attachment) == 2
    error_message = "Should create private and TGW attachment subnets in each AZ"
  }
  assert {
    condition     = aws_default_security_group.this.tags["Name"] == "test-spoke-default-sg-locked"
    error_message = "Default security group must be locked down on the spoke VPC"
  }
}

run "no_tgw_attachment_without_id" {
  command = plan
  module {
    source = "./modules/spoke-vpc"
  }
  variables {
    transit_gateway_id = null
  }

  assert {
    condition     = length(aws_ec2_transit_gateway_vpc_attachment.this) == 0
    error_message = "Should not create a TGW attachment when transit_gateway_id is null"
  }
}

run "rejects_unknown_environment" {
  command = plan
  module {
    source = "./modules/spoke-vpc"
  }
  variables {
    environment = "sandbox"
  }
  expect_failures = [
    var.environment,
  ]
}

run "ssm_endpoints_disabled" {
  command = plan
  module {
    source = "./modules/spoke-vpc"
  }

  assert {
    condition     = length(aws_vpc_endpoint.ssm) == 0
    error_message = "SSM endpoints should honor enable_ssm_endpoints=false"
  }
}
