# Shared services: resolver endpoints optional, private zone created.

mock_provider "aws" {}

variables {
  name                      = "test-shared-services"
  cidr_block                = "10.1.0.0/24"
  az_count                  = 2
  availability_zones        = ["us-east-1a", "us-east-1b"]
  enable_resolver_endpoints = false
  enable_forwarding_rules   = false
  enable_private_zones      = true
  private_zone_names        = ["aws.example.internal"]
  enable_flow_logs          = false
  tags = {
    Environment = "test"
  }
}

run "private_zone_without_resolver_cost" {
  command = plan
  module {
    source = "./modules/shared-services-vpc"
  }

  assert {
    condition     = length(aws_route53_zone.private) == 1
    error_message = "Should create the private hosted zone"
  }
  assert {
    condition     = length(aws_route53_resolver_endpoint.inbound) == 0
    error_message = "Inbound resolver must be off when disabled"
  }
  assert {
    condition     = length(aws_route53_resolver_endpoint.outbound) == 0
    error_message = "Outbound resolver must be off when disabled"
  }
}

run "resolver_endpoints_when_enabled" {
  command = plan
  module {
    source = "./modules/shared-services-vpc"
  }
  variables {
    enable_resolver_endpoints = true
    enable_forwarding_rules   = false
  }

  assert {
    condition     = length(aws_route53_resolver_endpoint.inbound) == 1
    error_message = "Should create inbound resolver endpoint"
  }
  assert {
    condition     = length(aws_route53_resolver_endpoint.outbound) == 1
    error_message = "Should create outbound resolver endpoint"
  }
  assert {
    condition     = length(aws_subnet.resolver) == 2
    error_message = "Resolver ENIs require a subnet per AZ"
  }
}
