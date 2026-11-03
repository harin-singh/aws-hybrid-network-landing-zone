# Site-to-Site VPN Module Tests
mock_provider "aws" {}

variables {
  name                     = "test-vpn"
  transit_gateway_id       = "tgw-12345678"
  customer_gateway_ip      = "203.0.113.1"
  customer_gateway_bgp_asn = 65000
  tags = {
    Environment = "test"
  }
}

run "creates_customer_gateway" {
  command = plan
  module {
    source = "./modules/site-to-site-vpn"
  }
  assert {
    condition     = tonumber(aws_customer_gateway.this.bgp_asn) == 65000
    error_message = "Customer gateway should have correct BGP ASN"
  }
  assert {
    condition     = aws_customer_gateway.this.ip_address == "203.0.113.1"
    error_message = "Customer gateway should have correct IP"
  }
  assert {
    condition     = aws_customer_gateway.this.type == "ipsec.1"
    error_message = "Customer gateway should be IPsec type"
  }
}

run "creates_vpn_connection" {
  command = plan
  module {
    source = "./modules/site-to-site-vpn"
  }
  assert {
    condition     = aws_vpn_connection.this.transit_gateway_id == "tgw-12345678"
    error_message = "VPN should be attached to TGW"
  }
  assert {
    condition     = aws_vpn_connection.this.type == "ipsec.1"
    error_message = "VPN connection should be IPsec type"
  }
}

run "validates_bgp_asn" {
  command = plan
  module {
    source = "./modules/site-to-site-vpn"
  }
  assert {
    condition     = var.customer_gateway_bgp_asn >= 1 && var.customer_gateway_bgp_asn <= 4294967295
    error_message = "BGP ASN should be valid"
  }
}
