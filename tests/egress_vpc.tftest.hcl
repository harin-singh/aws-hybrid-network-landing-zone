# Egress VPC: NAT count follows single_nat_gateway.

mock_provider "aws" {}

variables {
  name               = "test-egress"
  cidr_block         = "10.0.0.0/24"
  az_count           = 2
  availability_zones = ["us-east-1a", "us-east-1b"]
  single_nat_gateway = true
  enable_flow_logs   = false
  tags = {
    Environment = "test"
  }
}

run "single_nat_gateway" {
  command = plan
  module {
    source = "./modules/egress-vpc"
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "single_nat_gateway=true should create one NAT gateway"
  }
  assert {
    condition     = length(aws_subnet.public) == 2
    error_message = "Public subnets should still span both AZs"
  }
}

run "nat_per_az" {
  command = plan
  module {
    source = "./modules/egress-vpc"
  }
  variables {
    single_nat_gateway = false
  }

  assert {
    condition     = length(aws_nat_gateway.this) == 2
    error_message = "single_nat_gateway=false should create one NAT per AZ"
  }
}
