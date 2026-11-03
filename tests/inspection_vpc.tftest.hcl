# Inspection VPC: default-drop firewall and no prod<->nonprod pass rules.

mock_provider "aws" {}

variables {
  name                 = "test-inspection"
  cidr_block           = "10.0.0.0/24"
  az_count             = 2
  availability_zones   = ["us-east-1a", "us-east-1b"]
  enable_egress        = true
  single_nat_gateway   = true
  enable_firewall_logs = false
  enable_flow_logs     = false
  prod_cidrs           = ["10.10.0.0/24"]
  nonprod_cidrs        = ["10.20.0.0/24"]
  shared_cidrs         = ["10.1.0.0/24"]
  onprem_cidrs         = ["10.200.0.0/16", "192.168.100.0/24"]
  tags = {
    Environment = "test"
  }
}

run "firewall_policy_defaults_to_drop" {
  command = plan
  module {
    source = "./modules/inspection-vpc"
  }

  assert {
    condition     = contains(aws_networkfirewall_firewall_policy.this.firewall_policy[0].stateful_default_actions, "aws:drop_established")
    error_message = "Firewall policy must default to aws:drop_established under STRICT_ORDER"
  }
  assert {
    condition     = aws_networkfirewall_firewall_policy.this.firewall_policy[0].stateful_engine_options[0].rule_order == "STRICT_ORDER"
    error_message = "Firewall policy must use STRICT_ORDER"
  }
}

run "segmentation_rules_deny_prod_nonprod" {
  command = plan
  module {
    source = "./modules/inspection-vpc"
  }

  assert {
    condition     = strcontains(aws_networkfirewall_rule_group.segmentation.rule_group[0].rules_source[0].rules_string, "Deny prod to nonprod")
    error_message = "Segmentation rules must drop prod to nonprod"
  }
  assert {
    condition     = strcontains(aws_networkfirewall_rule_group.segmentation.rule_group[0].rules_source[0].rules_string, "Deny nonprod to prod")
    error_message = "Segmentation rules must drop nonprod to prod"
  }
  assert {
    condition     = strcontains(aws_networkfirewall_rule_group.segmentation.rule_group[0].rules_source[0].rules_string, "Deny nonprod to onprem")
    error_message = "Segmentation rules must drop nonprod to on-prem"
  }
  assert {
    condition     = !strcontains(aws_networkfirewall_rule_group.segmentation.rule_group[0].rules_source[0].rules_string, "pass icmp any any")
    error_message = "Must not contain an unconditional ICMP pass"
  }
  assert {
    condition     = !strcontains(aws_networkfirewall_rule_group.segmentation.rule_group[0].rules_source[0].rules_string, "pass tcp $HOME_NET any -> any any")
    error_message = "Must not contain a pass-all HOME_NET TCP rule"
  }
}

run "segmentation_rules_allow_intended_east_west" {
  command = plan
  module {
    source = "./modules/inspection-vpc"
  }

  assert {
    condition     = strcontains(aws_networkfirewall_rule_group.segmentation.rule_group[0].rules_source[0].rules_string, "Allow prod to shared")
    error_message = "Prod to shared services must be explicitly allowed"
  }
  assert {
    condition     = strcontains(aws_networkfirewall_rule_group.segmentation.rule_group[0].rules_source[0].rules_string, "Allow prod to onprem")
    error_message = "Prod to on-prem must be explicitly allowed"
  }
  assert {
    condition     = strcontains(aws_networkfirewall_rule_group.segmentation.rule_group[0].rules_source[0].rules_string, "Allow nonprod to shared")
    error_message = "Nonprod to shared services must be explicitly allowed"
  }
}

run "appliance_mode_and_nat" {
  command = plan
  module {
    source = "./modules/inspection-vpc"
  }
  variables {
    transit_gateway_id = "tgw-0123456789abcdefg"
  }

  assert {
    condition     = aws_ec2_transit_gateway_vpc_attachment.this[0].appliance_mode_support == "enable"
    error_message = "Inspection attachment must enable appliance mode for symmetric routing"
  }
  assert {
    condition     = length(aws_nat_gateway.this) == 1
    error_message = "single_nat_gateway=true should create one NAT gateway"
  }
}

run "creates_per_az_firewall_subnets" {
  command = plan
  module {
    source = "./modules/inspection-vpc"
  }

  assert {
    condition     = length(aws_subnet.firewall) == 2
    error_message = "Should create a firewall subnet in each AZ"
  }
  assert {
    condition     = aws_default_security_group.this.tags["Name"] == "test-inspection-default-sg-locked"
    error_message = "Default security group must be locked down on the inspection VPC"
  }
}
