output "transit_gateway_id" {
  description = "ID of the Transit Gateway"
  value       = module.transit_gateway.transit_gateway_id
}

output "egress_vpc_id" {
  description = "ID of the egress VPC"
  value       = module.egress_vpc.vpc_id
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

output "nat_gateway_public_ip" {
  description = "Public IP of NAT gateway"
  value       = module.egress_vpc.nat_gateway_public_ips[0]
}

output "tgw_route_table_ids" {
  description = "Transit Gateway route table IDs"
  value       = module.transit_gateway.route_table_ids
}
