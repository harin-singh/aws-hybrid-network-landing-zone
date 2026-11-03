# Inspection VPC Module Tests
mock_provider "aws" {}

variables {
  name                 = "test-inspection"
  cidr_block           = "10.0.0.0/24"
  az_count             = 2
  availability_zones   = ["us-west-2a", "us-west-2b"]
  enable_egress        = true
  single_nat_gateway   = true
  enable_firewall_logs = false
  enable_flow_logs     = false
  tags = {
    Environment = "test"
  }
}

run "creates_vpc" {
  command = plan
  module {
    source = "./modules/inspection-vpc"
  }
  assert {
    condition     = aws_vpc.this.cidr_block == "10.0.0.0/24"
    error_message = "VPC should have correct CIDR block"
  }
}

run "creates_firewall_subnets" {
  command = plan
  module {
    source = "./modules/inspection-vpc"
  }
  assert {
    condition     = length(aws_subnet.firewall) == 2
    error_message = "Should create firewall subnets for each AZ"
  }
}

run "creates_public_subnets_when_egress_enabled" {
  command = plan
  module {
    source = "./modules/inspection-vpc"
  }
  variables {
    enable_egress = true
  }
  assert {
    condition     = length(aws_subnet.public) == 2
    error_message = "Should create public subnets when egress enabled"
  }
}

run "creates_single_nat_gateway" {
  command = plan
  module {
    source = "./modules/inspection-vpc"
  }
  variables {
    single_nat_gateway = true
  }
  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "Should create single NAT gateway"
  }
  assert {
    condition     = length(aws_eip.nat) == 1
    error_message = "Should create single EIP for NAT"
  }
}

run "creates_network_firewall" {
  command = plan
  module {
    source = "./modules/inspection-vpc"
  }
  assert {
    condition     = aws_networkfirewall_firewall.this.name == "test-inspection"
    error_message = "Network Firewall should be created"
  }
}

run "creates_firewall_policy" {
  command = plan
  module {
    source = "./modules/inspection-vpc"
  }
  assert {
    condition     = aws_networkfirewall_firewall_policy.this.name == "test-inspection-policy"
    error_message = "Firewall policy should be created"
  }
}
