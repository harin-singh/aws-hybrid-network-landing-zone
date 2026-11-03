output "transit_gateway_id" {
  description = "ID of the Transit Gateway"
  value       = module.transit_gateway.transit_gateway_id
}

output "transit_gateway_arn" {
  description = "ARN of the Transit Gateway"
  value       = module.transit_gateway.transit_gateway_arn
}

#------------------------------------------------------------------------------
# VPC IDs
#------------------------------------------------------------------------------

output "inspection_vpc_id" {
  description = "ID of the inspection VPC"
  value       = module.inspection_vpc.vpc_id
}

output "shared_services_vpc_id" {
  description = "ID of the shared services VPC"
  value       = module.shared_services_vpc.vpc_id
}

output "prod_vpc_id" {
  description = "ID of the production spoke VPC"
  value       = module.prod_spoke_vpc.vpc_id
}

output "nonprod_vpc_id" {
  description = "ID of the non-production spoke VPC"
  value       = module.nonprod_spoke_vpc.vpc_id
}

output "simulated_onprem_vpc_id" {
  description = "ID of the simulated on-premises VPC"
  value       = module.simulated_onprem.vpc_id
}

#------------------------------------------------------------------------------
# Network Firewall
#------------------------------------------------------------------------------

output "network_firewall_id" {
  description = "ID of the Network Firewall"
  value       = module.inspection_vpc.firewall_id
}

output "network_firewall_endpoints" {
  description = "Network Firewall endpoint IDs by AZ"
  value       = module.inspection_vpc.firewall_endpoint_ids
}

#------------------------------------------------------------------------------
# NAT Gateway
#------------------------------------------------------------------------------

output "nat_gateway_public_ips" {
  description = "Public IPs of NAT gateways (for allowlisting)"
  value       = module.inspection_vpc.nat_gateway_public_ips
}

#------------------------------------------------------------------------------
# VPN
#------------------------------------------------------------------------------

output "vpn_connection_id" {
  description = "ID of the VPN connection"
  value       = module.site_to_site_vpn.vpn_connection_id
}

output "vpn_tunnel1_address" {
  description = "Public IP of VPN tunnel 1"
  value       = module.site_to_site_vpn.tunnel1_address
}

output "vpn_tunnel2_address" {
  description = "Public IP of VPN tunnel 2"
  value       = module.site_to_site_vpn.tunnel2_address
}

#------------------------------------------------------------------------------
# Simulated On-Premises
#------------------------------------------------------------------------------

output "onprem_router_public_ip" {
  description = "Public IP of the simulated on-premises router"
  value       = module.simulated_onprem.router_public_ip
}

output "onprem_router_instance_id" {
  description = "Instance ID of the on-premises router (for SSM)"
  value       = module.simulated_onprem.router_instance_id
}

#------------------------------------------------------------------------------
# DNS
#------------------------------------------------------------------------------

output "resolver_inbound_ips" {
  description = "Inbound resolver endpoint IPs (for on-prem DNS forwarding)"
  value       = module.shared_services_vpc.resolver_inbound_endpoint_ips
}

output "private_hosted_zones" {
  description = "Private hosted zone IDs"
  value       = module.shared_services_vpc.private_zone_ids
}

#------------------------------------------------------------------------------
# Test Instances
#------------------------------------------------------------------------------

output "prod_test_instance_id" {
  description = "Instance ID of prod test instance (for SSM)"
  value       = aws_instance.prod_test.id
}

output "prod_test_instance_private_ip" {
  description = "Private IP of prod test instance"
  value       = aws_instance.prod_test.private_ip
}

output "nonprod_test_instance_id" {
  description = "Instance ID of nonprod test instance (for SSM)"
  value       = aws_instance.nonprod_test.id
}

output "nonprod_test_instance_private_ip" {
  description = "Private IP of nonprod test instance"
  value       = aws_instance.nonprod_test.private_ip
}

output "onprem_test_instance_id" {
  description = "Instance ID of on-prem test instance"
  value       = module.simulated_onprem.test_instance_id
}

output "onprem_test_instance_private_ip" {
  description = "Private IP of on-prem test instance"
  value       = module.simulated_onprem.test_instance_private_ip
}

#------------------------------------------------------------------------------
# Route Tables Summary
#------------------------------------------------------------------------------

output "tgw_route_table_ids" {
  description = "Transit Gateway route table IDs"
  value       = module.transit_gateway.route_table_ids
}
