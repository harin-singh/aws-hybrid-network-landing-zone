output "vpc_id" {
  description = "ID of the shared services VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "resolver_subnet_ids" {
  description = "List of resolver subnet IDs"
  value       = aws_subnet.resolver[*].id
}

output "tgw_attachment_subnet_ids" {
  description = "List of TGW attachment subnet IDs"
  value       = aws_subnet.tgw_attachment[*].id
}

output "tgw_attachment_id" {
  description = "ID of the Transit Gateway VPC attachment"
  value       = var.transit_gateway_id != null ? aws_ec2_transit_gateway_vpc_attachment.this[0].id : null
}

#------------------------------------------------------------------------------
# Resolver Outputs
#------------------------------------------------------------------------------

output "resolver_inbound_endpoint_id" {
  description = "ID of the Route 53 Resolver inbound endpoint"
  value       = var.enable_resolver_endpoints ? aws_route53_resolver_endpoint.inbound[0].id : null
}

output "resolver_inbound_endpoint_ips" {
  description = "IP addresses of the inbound resolver endpoint"
  value       = var.enable_resolver_endpoints ? aws_route53_resolver_endpoint.inbound[0].ip_address[*].ip : []
}

output "resolver_outbound_endpoint_id" {
  description = "ID of the Route 53 Resolver outbound endpoint"
  value       = var.enable_resolver_endpoints ? aws_route53_resolver_endpoint.outbound[0].id : null
}

output "resolver_rule_ids" {
  description = "Map of domain to resolver rule ID"
  value = var.enable_resolver_endpoints && var.enable_forwarding_rules ? {
    for domain, rule in aws_route53_resolver_rule.forward : domain => rule.id
  } : {}
}

output "resolver_rule_arns" {
  description = "Map of domain to resolver rule ARN"
  value = var.enable_resolver_endpoints && var.enable_forwarding_rules ? {
    for domain, rule in aws_route53_resolver_rule.forward : domain => rule.arn
  } : {}
}

#------------------------------------------------------------------------------
# Private Hosted Zones
#------------------------------------------------------------------------------

output "private_zone_ids" {
  description = "Map of zone name to zone ID"
  value = var.enable_private_zones ? {
    for name, zone in aws_route53_zone.private : name => zone.zone_id
  } : {}
}

output "private_zone_name_servers" {
  description = "Map of zone name to name servers"
  value = var.enable_private_zones ? {
    for name, zone in aws_route53_zone.private : name => zone.name_servers
  } : {}
}

#------------------------------------------------------------------------------
# RAM Share
#------------------------------------------------------------------------------

output "resolver_rules_ram_share_arn" {
  description = "ARN of the RAM share for resolver rules"
  value       = var.enable_resolver_endpoints && var.enable_forwarding_rules && var.share_resolver_rules && length(var.ram_principals) > 0 ? aws_ram_resource_share.resolver_rules[0].arn : null
}

output "availability_zones" {
  description = "List of availability zones used"
  value       = local.azs
}

output "flow_log_group_arn" {
  description = "ARN of the VPC flow logs CloudWatch log group"
  value       = var.enable_flow_logs ? aws_cloudwatch_log_group.flow_logs[0].arn : null
}
