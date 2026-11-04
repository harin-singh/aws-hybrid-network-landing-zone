output "transit_gateway_id" {
  description = "Transit Gateway ID owned by the network account"
  value       = module.transit_gateway.transit_gateway_id
}

output "ram_resource_share_arn" {
  description = "RAM share ARN for the Transit Gateway"
  value       = module.transit_gateway.ram_resource_share_arn
}

output "inspection_vpc_id" {
  description = "Inspection VPC ID in the network account"
  value       = module.inspection_vpc.vpc_id
}

output "workload_vpc_id" {
  description = "Spoke VPC ID in the workload account"
  value       = module.workload_spoke.vpc_id
}

output "workload_tgw_attachment_id" {
  description = "Workload VPC attachment ID"
  value       = module.workload_spoke.tgw_attachment_id
}

output "protect_network_scp_id" {
  description = "Organizations SCP ID (not attached unless scp_target_id is set)"
  value       = aws_organizations_policy.protect_network.id
}
