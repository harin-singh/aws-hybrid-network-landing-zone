# Egress VPC Module Tests
mock_provider "aws" {}

variables {
  name               = "test-egress"
  cidr_block         = "10.0.0.0/24"
  az_count           = 2
  availability_zones = ["us-west-2a", "us-west-2b"]
  single_nat_gateway = true
  enable_flow_logs   = false
  tags = {
    Environment = "test"
  }
}

run "creates_vpc" {
  command = plan
  module {
    source = "./modules/egress-vpc"
  }
  assert {
    condition     = aws_vpc.this.cidr_block == "10.0.0.0/24"
    error_message = "VPC should have correct CIDR block"
  }
}

run "creates_public_subnets" {
  command = plan
  module {
    source = "./modules/egress-vpc"
  }
  assert {
    condition     = length(aws_subnet.public) == 2
    error_message = "Should create public subnets for each AZ"
  }
}

run "creates_single_nat_gateway" {
  command = plan
  module {
    source = "./modules/egress-vpc"
  }
  variables {
    single_nat_gateway = true
  }
  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "Should create single NAT gateway"
  }
}

run "creates_multiple_nat_gateways" {
  command = plan
  module {
    source = "./modules/egress-vpc"
  }
  variables {
    single_nat_gateway = false
    az_count           = 2
    availability_zones = ["us-west-2a", "us-west-2b"]
  }
  assert {
    condition     = length(aws_nat_gateway.this) == 2
    error_message = "Should create NAT gateway per AZ"
  }
}
