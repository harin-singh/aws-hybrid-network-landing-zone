output "transit_gateway_id" {
  description = "ID of the Transit Gateway"
  value       = aws_ec2_transit_gateway.this.id
}

output "transit_gateway_arn" {
  description = "ARN of the Transit Gateway"
  value       = aws_ec2_transit_gateway.this.arn
}

output "transit_gateway_owner_id" {
  description = "Owner ID of the Transit Gateway"
  value       = aws_ec2_transit_gateway.this.owner_id
}

output "amazon_side_asn" {
  description = "Amazon side ASN configured on the Transit Gateway"
  value       = aws_ec2_transit_gateway.this.amazon_side_asn
}

#------------------------------------------------------------------------------
# Route Table IDs - Used by spoke modules for associations and propagations
#------------------------------------------------------------------------------

output "route_table_ids" {
  description = "Map of route table names to IDs"
  value = var.create_route_tables ? {
    prod            = aws_ec2_transit_gateway_route_table.prod[0].id
    nonprod         = aws_ec2_transit_gateway_route_table.nonprod[0].id
    shared_services = aws_ec2_transit_gateway_route_table.shared_services[0].id
    inspection      = aws_ec2_transit_gateway_route_table.inspection[0].id
    onprem          = aws_ec2_transit_gateway_route_table.onprem[0].id
  } : {}
}

output "prod_route_table_id" {
  description = "ID of the production route table"
  value       = var.create_route_tables ? aws_ec2_transit_gateway_route_table.prod[0].id : null
}

output "nonprod_route_table_id" {
  description = "ID of the non-production route table"
  value       = var.create_route_tables ? aws_ec2_transit_gateway_route_table.nonprod[0].id : null
}

output "shared_services_route_table_id" {
  description = "ID of the shared services route table"
  value       = var.create_route_tables ? aws_ec2_transit_gateway_route_table.shared_services[0].id : null
}

output "inspection_route_table_id" {
  description = "ID of the inspection route table"
  value       = var.create_route_tables ? aws_ec2_transit_gateway_route_table.inspection[0].id : null
}

output "onprem_route_table_id" {
  description = "ID of the on-premises route table"
  value       = var.create_route_tables ? aws_ec2_transit_gateway_route_table.onprem[0].id : null
}

#------------------------------------------------------------------------------
# Flow Logs
#------------------------------------------------------------------------------

output "flow_log_id" {
  description = "ID of the Transit Gateway flow log"
  value       = var.enable_flow_logs ? aws_flow_log.tgw[0].id : null
}

output "flow_log_group_arn" {
  description = "ARN of the CloudWatch log group for flow logs"
  value       = var.enable_flow_logs && var.flow_logs_destination_type == "cloud-watch-logs" ? aws_cloudwatch_log_group.tgw_flow_logs[0].arn : null
}

#------------------------------------------------------------------------------
# RAM Share
#------------------------------------------------------------------------------

output "ram_resource_share_arn" {
  description = "ARN of the RAM resource share for the Transit Gateway"
  value       = var.share_tgw && length(var.ram_principals) > 0 ? aws_ram_resource_share.tgw[0].arn : null
}
