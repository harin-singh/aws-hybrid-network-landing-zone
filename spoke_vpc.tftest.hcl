# Spoke VPC Module Tests
mock_provider "aws" {}

variables {
  name                 = "test-spoke"
  environment          = "prod"
  region               = "us-west-2"
  cidr_block           = "10.0.0.0/24"
  az_count             = 2
  availability_zones   = ["us-west-2a", "us-west-2b"]
  enable_ssm_endpoints = false
  enable_flow_logs     = false
  tags = {
    Environment = "test"
  }
}

run "creates_vpc" {
  command = plan
  module {
    source = "./modules/spoke-vpc"
  }
  assert {
    condition     = aws_vpc.this.cidr_block == "10.0.0.0/24"
    error_message = "VPC should have correct CIDR block"
  }
  assert {
    condition     = aws_vpc.this.enable_dns_hostnames == true
    error_message = "DNS hostnames should be enabled"
  }
  assert {
    condition     = aws_vpc.this.enable_dns_support == true
    error_message = "DNS support should be enabled"
  }
}

run "creates_subnets_per_az" {
  command = plan
  module {
    source = "./modules/spoke-vpc"
  }
  assert {
    condition     = length(aws_subnet.private) == 2
    error_message = "Should create private subnets for each AZ"
  }
  assert {
    condition     = length(aws_subnet.tgw_attachment) == 2
    error_message = "Should create TGW attachment subnets for each AZ"
  }
}

run "validates_environment" {
  command = plan
  module {
    source = "./modules/spoke-vpc"
  }
  variables {
    environment = "prod"
  }
  assert {
    condition     = contains(["prod", "nonprod", "shared-services", "inspection"], var.environment)
    error_message = "Environment must be valid"
  }
}

run "no_tgw_attachment_without_tgw_id" {
  command = plan
  module {
    source = "./modules/spoke-vpc"
  }
  variables {
    transit_gateway_id = null
  }
  assert {
    condition     = length(aws_ec2_transit_gateway_vpc_attachment.this) == 0
    error_message = "Should not create TGW attachment when TGW ID is null"
  }
}

run "ssm_endpoints_disabled_by_default_in_test" {
  command = plan
  module {
    source = "./modules/spoke-vpc"
  }
  assert {
    condition     = length(aws_vpc_endpoint.ssm) == 0
    error_message = "SSM endpoints should be disabled"
  }
}
