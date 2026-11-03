# Transit Gateway: segmentation primitives (disabled default RT, blackholes, RAM).

mock_provider "aws" {}

variables {
  name             = "test-tgw"
  amazon_side_asn  = 64512
  enable_flow_logs = false
  tags = {
    Environment = "test"
  }
}

run "default_route_table_is_not_used" {
  command = plan
  module {
    source = "./modules/transit-gateway"
  }

  assert {
    condition     = aws_ec2_transit_gateway.this.default_route_table_association == "disable"
    error_message = "Default route table association must be disabled so attachments cannot skip segmentation RTs"
  }
  assert {
    condition     = aws_ec2_transit_gateway.this.default_route_table_propagation == "disable"
    error_message = "Default route table propagation must be disabled so routes cannot leak across segments"
  }
  assert {
    condition     = aws_ec2_transit_gateway.this.amazon_side_asn == 64512
    error_message = "Transit Gateway should use the configured private ASN"
  }
}

run "creates_five_segment_route_tables" {
  command = plan
  module {
    source = "./modules/transit-gateway"
  }
  variables {
    create_route_tables = true
  }

  assert {
    condition     = length(aws_ec2_transit_gateway_route_table.prod) == 1 && length(aws_ec2_transit_gateway_route_table.nonprod) == 1 && length(aws_ec2_transit_gateway_route_table.shared_services) == 1 && length(aws_ec2_transit_gateway_route_table.inspection) == 1 && length(aws_ec2_transit_gateway_route_table.onprem) == 1
    error_message = "Expected prod, nonprod, shared_services, inspection, and onprem route tables"
  }
}

run "blackholes_denied_cidrs" {
  command = plan
  module {
    source = "./modules/transit-gateway"
  }
  variables {
    blackhole_routes = {
      prod    = ["10.20.0.0/24"]
      nonprod = ["10.10.0.0/24", "10.200.0.0/16"]
      onprem  = ["10.20.0.0/24"]
    }
  }

  assert {
    condition     = aws_ec2_transit_gateway_route.blackhole["prod:10.20.0.0/24"].blackhole == true
    error_message = "Prod RT must blackhole the nonprod CIDR"
  }
  assert {
    condition     = aws_ec2_transit_gateway_route.blackhole["nonprod:10.10.0.0/24"].blackhole == true
    error_message = "Nonprod RT must blackhole the prod CIDR"
  }
  assert {
    condition     = aws_ec2_transit_gateway_route.blackhole["nonprod:10.200.0.0/16"].blackhole == true
    error_message = "Nonprod RT must blackhole the on-prem CIDR"
  }
  assert {
    condition     = aws_ec2_transit_gateway_route.blackhole["onprem:10.20.0.0/24"].blackhole == true
    error_message = "On-prem RT must blackhole the nonprod CIDR"
  }
}

run "ram_share_created_when_enabled" {
  command = plan
  module {
    source = "./modules/transit-gateway"
  }
  variables {
    share_tgw      = true
    ram_principals = ["arn:aws:organizations::111111111111:ou/o-example/ou-workload"]
  }

  assert {
    condition     = length(aws_ram_resource_share.tgw) == 1
    error_message = "RAM share must be created when share_tgw is true"
  }
  assert {
    condition     = length(aws_ram_resource_association.tgw) == 1
    error_message = "TGW must be associated with the RAM share"
  }
}

run "skips_route_tables_when_disabled" {
  command = plan
  module {
    source = "./modules/transit-gateway"
  }
  variables {
    create_route_tables = false
  }

  assert {
    condition     = length(aws_ec2_transit_gateway_route_table.prod) == 0
    error_message = "Should not create route tables when disabled"
  }
}

run "rejects_asn_outside_private_range" {
  command = plan
  module {
    source = "./modules/transit-gateway"
  }
  variables {
    amazon_side_asn = 1
  }
  expect_failures = [
    var.amazon_side_asn,
  ]
}
