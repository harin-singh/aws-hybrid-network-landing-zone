output "vpc_id" {
  description = "ID of the inspection VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "firewall_subnet_ids" {
  description = "List of firewall subnet IDs"
  value       = aws_subnet.firewall[*].id
}

output "tgw_attachment_subnet_ids" {
  description = "List of TGW attachment subnet IDs"
  value       = aws_subnet.tgw_attachment[*].id
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = var.enable_egress ? aws_subnet.public[*].id : []
}

output "tgw_attachment_id" {
  description = "ID of the Transit Gateway VPC attachment"
  value       = var.transit_gateway_id != null ? aws_ec2_transit_gateway_vpc_attachment.this[0].id : null
}

output "firewall_id" {
  description = "ID of the Network Firewall"
  value       = aws_networkfirewall_firewall.this.id
}

output "firewall_arn" {
  description = "ARN of the Network Firewall"
  value       = aws_networkfirewall_firewall.this.arn
}

output "firewall_endpoint_ids" {
  description = "Map of AZ to firewall endpoint ID"
  value       = local.firewall_endpoints
}

output "firewall_policy_arn" {
  description = "ARN of the Network Firewall policy"
  value       = aws_networkfirewall_firewall_policy.this.arn
}

output "firewall_stateful_default_actions" {
  description = "Stateful default actions on the firewall policy"
  value       = aws_networkfirewall_firewall_policy.this.firewall_policy[0].stateful_default_actions
}

output "segmentation_rules_string" {
  description = "Suricata rules used for prod/nonprod/on-prem segmentation"
  value       = aws_networkfirewall_rule_group.segmentation.rule_group[0].rules_source[0].rules_string
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = var.enable_egress ? aws_nat_gateway.this[*].id : []
}

output "nat_gateway_public_ips" {
  description = "List of NAT Gateway public IPs"
  value       = var.enable_egress ? aws_eip.nat[*].public_ip : []
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = var.enable_egress ? aws_internet_gateway.this[0].id : null
}

output "firewall_alert_log_group_arn" {
  description = "ARN of the firewall alert log group"
  value       = var.enable_firewall_logs ? aws_cloudwatch_log_group.firewall_alert[0].arn : null
}

output "firewall_flow_log_group_arn" {
  description = "ARN of the firewall flow log group"
  value       = var.enable_firewall_logs ? aws_cloudwatch_log_group.firewall_flow[0].arn : null
}

output "availability_zones" {
  description = "List of availability zones used"
  value       = local.azs
}
