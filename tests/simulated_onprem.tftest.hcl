# Simulated on-prem: IMDSv2, encrypted EBS, PSK not in user_data, no 0.0.0.0/0 IPsec.

mock_provider "aws" {
  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b"]
    }
  }

  mock_data "aws_ami" {
    defaults = {
      id = "ami-0123456789abcdef0"
    }
  }

  mock_data "aws_iam_policy_document" {
    defaults = {
      json = "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Effect\":\"Allow\",\"Action\":\"kms:*\",\"Resource\":\"*\"}]}"
    }
  }
}

variables {
  name                 = "test-onprem"
  vpc_cidr             = "192.168.100.0/24"
  create_test_instance = true
  enable_flow_logs     = false
  tunnel1_aws_endpoint = "203.0.113.10"
  tunnel2_aws_endpoint = "203.0.113.11"
  tunnel1_psk          = "test-psk-tunnel-1-not-a-real-secret"
  tunnel2_psk          = "test-psk-tunnel-2-not-a-real-secret"
  ipsec_peer_cidrs     = ["203.0.113.10/32", "203.0.113.11/32"]
  tags = {
    Environment = "test"
  }
}

run "imdsv2_and_ebs_encryption" {
  command = plan
  module {
    source = "./modules/simulated-onprem"
  }

  assert {
    condition     = aws_instance.router.metadata_options[0].http_tokens == "required"
    error_message = "Router must require IMDSv2 (http_tokens=required)"
  }
  assert {
    condition     = aws_instance.router.root_block_device[0].encrypted == true
    error_message = "Router root volume must be encrypted"
  }
  assert {
    condition     = aws_instance.test[0].metadata_options[0].http_tokens == "required"
    error_message = "Test instance must require IMDSv2"
  }
  assert {
    condition     = aws_instance.test[0].root_block_device[0].encrypted == true
    error_message = "Test instance root volume must be encrypted"
  }
}

run "psk_not_in_userdata" {
  command = plan
  module {
    source = "./modules/simulated-onprem"
  }

  assert {
    condition     = !strcontains(aws_instance.router.user_data, var.tunnel1_psk)
    error_message = "Tunnel 1 PSK must not appear in EC2 user_data"
  }
  assert {
    condition     = !strcontains(aws_instance.router.user_data, var.tunnel2_psk)
    error_message = "Tunnel 2 PSK must not appear in EC2 user_data"
  }
  assert {
    condition     = strcontains(aws_instance.router.user_data, "ssm get-parameter")
    error_message = "user_data must fetch PSKs from SSM Parameter Store at boot"
  }
}

run "ipsec_ingress_not_world_open" {
  command = plan
  module {
    source = "./modules/simulated-onprem"
  }

  assert {
    condition = alltrue([
      for rule in aws_security_group.router.ingress :
      !(rule.from_port == 500 && contains(rule.cidr_blocks, "0.0.0.0/0"))
    ])
    error_message = "IKE must not be open to 0.0.0.0/0"
  }
  assert {
    condition = alltrue([
      for rule in aws_security_group.router.ingress :
      !(rule.from_port == 4500 && contains(rule.cidr_blocks, "0.0.0.0/0"))
    ])
    error_message = "NAT-T must not be open to 0.0.0.0/0"
  }
}

run "stores_psks_in_ssm" {
  command = plan
  module {
    source = "./modules/simulated-onprem"
  }

  assert {
    condition     = aws_ssm_parameter.tunnel1_psk[0].type == "SecureString"
    error_message = "Tunnel 1 PSK must be an SSM SecureString"
  }
  assert {
    condition     = aws_ssm_parameter.tunnel2_psk[0].type == "SecureString"
    error_message = "Tunnel 2 PSK must be an SSM SecureString"
  }
}
