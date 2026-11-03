# Site-to-Site VPN: TGW attachment, IKEv2, BGP ASN.

mock_provider "aws" {}

variables {
  name                     = "test-vpn"
  transit_gateway_id       = "tgw-0123456789abcdefg"
  customer_gateway_ip      = "203.0.113.1"
  customer_gateway_bgp_asn = 65000
  tags = {
    Environment = "test"
  }
}

run "creates_bgp_vpn_on_tgw" {
  command = plan
  module {
    source = "./modules/site-to-site-vpn"
  }

  assert {
    condition     = tonumber(aws_customer_gateway.this.bgp_asn) == 65000
    error_message = "Customer gateway ASN must be 65000"
  }
  assert {
    condition     = aws_vpn_connection.this.transit_gateway_id == "tgw-0123456789abcdefg"
    error_message = "VPN must attach to the supplied Transit Gateway"
  }
  assert {
    condition     = aws_vpn_connection.this.type == "ipsec.1"
    error_message = "VPN connection type must be ipsec.1"
  }
  assert {
    condition     = contains(aws_vpn_connection.this.tunnel1_ike_versions, "ikev2")
    error_message = "Tunnel 1 must allow IKEv2"
  }
}

run "rejects_invalid_customer_asn" {
  command = plan
  module {
    source = "./modules/site-to-site-vpn"
  }
  variables {
    customer_gateway_bgp_asn = 0
  }
  expect_failures = [
    var.customer_gateway_bgp_asn,
  ]
}
