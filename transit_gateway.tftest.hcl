# Transit Gateway Module Tests
mock_provider "aws" {}

variables {
  name             = "test-tgw"
  amazon_side_asn  = 64512
  enable_flow_logs = false
  tags = {
    Environment = "test"
  }
}

run "creates_transit_gateway" {
  command = plan
  module {
    source = "./modules/transit-gateway"
  }
  assert {
    condition     = aws_ec2_transit_gateway.this.amazon_side_asn == 64512
    error_message = "Transit Gateway should have ASN 64512"
  }
  assert {
    condition     = aws_ec2_transit_gateway.this.default_route_table_association == "disable"
    error_message = "Default route table association should be disabled"
  }
  assert {
    condition     = aws_ec2_transit_gateway.this.default_route_table_propagation == "disable"
    error_message = "Default route table propagation should be disabled"
  }
}

run "creates_segmented_route_tables" {
  command = plan
  module {
    source = "./modules/transit-gateway"
  }
  variables {
    create_route_tables = true
  }
  assert {
    condition     = length(aws_ec2_transit_gateway_route_table.prod) == 1
    error_message = "Should create prod route table"
  }
  assert {
    condition     = length(aws_ec2_transit_gateway_route_table.nonprod) == 1
    error_message = "Should create nonprod route table"
  }
  assert {
    condition     = length(aws_ec2_transit_gateway_route_table.shared_services) == 1
    error_message = "Should create shared services route table"
  }
  assert {
    condition     = length(aws_ec2_transit_gateway_route_table.inspection) == 1
    error_message = "Should create inspection route table"
  }
  assert {
    condition     = length(aws_ec2_transit_gateway_route_table.onprem) == 1
    error_message = "Should create onprem route table"
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

run "validates_asn_range" {
  command = plan
  module {
    source = "./modules/transit-gateway"
  }
  variables {
    amazon_side_asn = 64512
  }
  assert {
    condition     = var.amazon_side_asn >= 64512 && var.amazon_side_asn <= 65534
    error_message = "ASN should be in valid private range"
  }
}
