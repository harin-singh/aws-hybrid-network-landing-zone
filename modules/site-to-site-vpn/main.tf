#------------------------------------------------------------------------------
# Site-to-Site VPN - TGW VPN Attachment with BGP
#
# Design decisions:
# - TGW VPN attachment: Direct attachment to Transit Gateway (not VGW)
# - BGP routing: Dynamic route exchange with on-premises
# - Dual tunnels: Redundant tunnels for high availability
# - Configurable ASNs: Flexible BGP configuration
#
# This module creates AWS resources only. The remote endpoint (customer gateway
# device) must be configured separately - see simulated-onprem module for a
# test setup using strongSwan + FRR.
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# Customer Gateway - Represents the on-premises router
#------------------------------------------------------------------------------

resource "aws_customer_gateway" "this" {
  bgp_asn    = var.customer_gateway_bgp_asn
  ip_address = var.customer_gateway_ip
  type       = "ipsec.1"

  device_name = var.customer_gateway_device_name

  tags = merge(var.tags, {
    Name = var.name
  })
}

#------------------------------------------------------------------------------
# VPN Connection - TGW attachment with BGP
#------------------------------------------------------------------------------

resource "aws_vpn_connection" "this" {
  customer_gateway_id = aws_customer_gateway.this.id
  transit_gateway_id  = var.transit_gateway_id
  type                = "ipsec.1"

  enable_acceleration = var.enable_acceleration

  tunnel1_inside_cidr   = var.tunnel1_inside_cidr
  tunnel2_inside_cidr   = var.tunnel2_inside_cidr
  tunnel1_preshared_key = var.tunnel1_psk
  tunnel2_preshared_key = var.tunnel2_psk

  tunnel1_ike_versions = var.tunnel_ike_versions
  tunnel2_ike_versions = var.tunnel_ike_versions

  tunnel1_phase1_dh_group_numbers      = var.tunnel_phase1_dh_groups
  tunnel2_phase1_dh_group_numbers      = var.tunnel_phase1_dh_groups
  tunnel1_phase1_encryption_algorithms = var.tunnel_phase1_encryption
  tunnel2_phase1_encryption_algorithms = var.tunnel_phase1_encryption
  tunnel1_phase1_integrity_algorithms  = var.tunnel_phase1_integrity
  tunnel2_phase1_integrity_algorithms  = var.tunnel_phase1_integrity

  tunnel1_phase2_dh_group_numbers      = var.tunnel_phase2_dh_groups
  tunnel2_phase2_dh_group_numbers      = var.tunnel_phase2_dh_groups
  tunnel1_phase2_encryption_algorithms = var.tunnel_phase2_encryption
  tunnel2_phase2_encryption_algorithms = var.tunnel_phase2_encryption
  tunnel1_phase2_integrity_algorithms  = var.tunnel_phase2_integrity
  tunnel2_phase2_integrity_algorithms  = var.tunnel_phase2_integrity

  tunnel1_startup_action = var.tunnel_startup_action
  tunnel2_startup_action = var.tunnel_startup_action

  tunnel1_dpd_timeout_action = var.tunnel_dpd_timeout_action
  tunnel2_dpd_timeout_action = var.tunnel_dpd_timeout_action

  tags = merge(var.tags, {
    Name = var.name
  })
}

#------------------------------------------------------------------------------
# TGW Route Table Association
#------------------------------------------------------------------------------

data "aws_ec2_transit_gateway_vpn_attachment" "this" {
  transit_gateway_id = var.transit_gateway_id
  vpn_connection_id  = aws_vpn_connection.this.id
}

resource "aws_ec2_transit_gateway_route_table_association" "this" {
  count = var.tgw_route_table_id != null ? 1 : 0

  transit_gateway_attachment_id  = data.aws_ec2_transit_gateway_vpn_attachment.this.id
  transit_gateway_route_table_id = var.tgw_route_table_id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "this" {
  for_each = toset(var.tgw_propagation_route_table_ids)

  transit_gateway_attachment_id  = data.aws_ec2_transit_gateway_vpn_attachment.this.id
  transit_gateway_route_table_id = each.value
}

#------------------------------------------------------------------------------
# Static Routes (optional, in addition to BGP)
#------------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_route" "static" {
  for_each = var.static_routes_to_onprem

  destination_cidr_block         = each.value
  transit_gateway_attachment_id  = data.aws_ec2_transit_gateway_vpn_attachment.this.id
  transit_gateway_route_table_id = each.key
}
