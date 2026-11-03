# Shared Services VPC Module Tests
mock_provider "aws" {}

variables {
  name                      = "test-shared-services"
  cidr_block                = "10.1.0.0/24"
  az_count                  = 2
  availability_zones        = ["us-west-2a", "us-west-2b"]
  enable_resolver_endpoints = false
  enable_forwarding_rules   = false
  enable_private_zones      = true
  private_zone_names        = ["test.internal"]
  enable_flow_logs          = false
  tags = {
    Environment = "test"
  }
}

run "creates_vpc" {
  command = plan
  module {
    source = "./modules/shared-services-vpc"
  }
  assert {
    condition     = aws_vpc.this.cidr_block == "10.1.0.0/24"
    error_message = "VPC should have correct CIDR block"
  }
}

run "creates_resolver_subnets" {
  command = plan
  module {
    source = "./modules/shared-services-vpc"
  }
  assert {
    condition     = length(aws_subnet.resolver) == 2
    error_message = "Should create resolver subnets"
  }
}

run "creates_private_hosted_zone" {
  command = plan
  module {
    source = "./modules/shared-services-vpc"
  }
  assert {
    condition     = length(aws_route53_zone.private) == 1
    error_message = "Should create private hosted zone"
  }
}

run "no_resolver_endpoints_when_disabled" {
  command = plan
  module {
    source = "./modules/shared-services-vpc"
  }
  variables {
    enable_resolver_endpoints = false
  }
  assert {
    condition     = length(aws_route53_resolver_endpoint.inbound) == 0
    error_message = "Should not create inbound resolver endpoint when disabled"
  }
  assert {
    condition     = length(aws_route53_resolver_endpoint.outbound) == 0
    error_message = "Should not create outbound resolver endpoint when disabled"
  }
}
