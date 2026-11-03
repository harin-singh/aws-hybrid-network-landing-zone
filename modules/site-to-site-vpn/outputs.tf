output "customer_gateway_id" {
  description = "ID of the customer gateway"
  value       = aws_customer_gateway.this.id
}

output "vpn_connection_id" {
  description = "ID of the VPN connection"
  value       = aws_vpn_connection.this.id
}

output "vpn_connection_arn" {
  description = "ARN of the VPN connection"
  value       = aws_vpn_connection.this.arn
}

output "tgw_attachment_id" {
  description = "ID of the TGW VPN attachment"
  value       = data.aws_ec2_transit_gateway_vpn_attachment.this.id
}

#------------------------------------------------------------------------------
# Tunnel Configuration - For configuring the customer gateway device
#------------------------------------------------------------------------------

output "tunnel1_address" {
  description = "Public IP address of VPN tunnel 1"
  value       = aws_vpn_connection.this.tunnel1_address
}

output "tunnel1_cgw_inside_address" {
  description = "Customer gateway inside address for tunnel 1"
  value       = aws_vpn_connection.this.tunnel1_cgw_inside_address
}

output "tunnel1_vgw_inside_address" {
  description = "Virtual gateway (AWS) inside address for tunnel 1"
  value       = aws_vpn_connection.this.tunnel1_vgw_inside_address
}

output "tunnel1_bgp_asn" {
  description = "BGP ASN on AWS side for tunnel 1"
  value       = aws_vpn_connection.this.tunnel1_bgp_asn
}

output "tunnel1_bgp_holdtime" {
  description = "BGP hold time for tunnel 1"
  value       = aws_vpn_connection.this.tunnel1_bgp_holdtime
}

output "tunnel1_preshared_key" {
  description = "Pre-shared key for tunnel 1"
  value       = aws_vpn_connection.this.tunnel1_preshared_key
  sensitive   = true
}

output "tunnel2_address" {
  description = "Public IP address of VPN tunnel 2"
  value       = aws_vpn_connection.this.tunnel2_address
}

output "tunnel2_cgw_inside_address" {
  description = "Customer gateway inside address for tunnel 2"
  value       = aws_vpn_connection.this.tunnel2_cgw_inside_address
}

output "tunnel2_vgw_inside_address" {
  description = "Virtual gateway (AWS) inside address for tunnel 2"
  value       = aws_vpn_connection.this.tunnel2_vgw_inside_address
}

output "tunnel2_bgp_asn" {
  description = "BGP ASN on AWS side for tunnel 2"
  value       = aws_vpn_connection.this.tunnel2_bgp_asn
}

output "tunnel2_bgp_holdtime" {
  description = "BGP hold time for tunnel 2"
  value       = aws_vpn_connection.this.tunnel2_bgp_holdtime
}

output "tunnel2_preshared_key" {
  description = "Pre-shared key for tunnel 2"
  value       = aws_vpn_connection.this.tunnel2_preshared_key
  sensitive   = true
}

#------------------------------------------------------------------------------
# VPN Configuration XML - For customer gateway device setup
#------------------------------------------------------------------------------

output "customer_gateway_configuration" {
  description = "XML configuration for customer gateway device"
  value       = aws_vpn_connection.this.customer_gateway_configuration
  sensitive   = true
}
