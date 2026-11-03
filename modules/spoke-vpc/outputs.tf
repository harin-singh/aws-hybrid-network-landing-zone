output "vpc_id" {
  description = "ID of the VPC"
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

output "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks"
  value       = aws_subnet.private[*].cidr_block
}

output "tgw_attachment_subnet_ids" {
  description = "List of TGW attachment subnet IDs"
  value       = aws_subnet.tgw_attachment[*].id
}

output "tgw_attachment_id" {
  description = "ID of the Transit Gateway VPC attachment"
  value       = var.transit_gateway_id != null ? aws_ec2_transit_gateway_vpc_attachment.this[0].id : null
}

output "private_route_table_id" {
  description = "ID of the private route table"
  value       = aws_route_table.private.id
}

output "vpc_endpoints_security_group_id" {
  description = "ID of the VPC endpoints security group"
  value       = var.enable_ssm_endpoints ? aws_security_group.vpc_endpoints[0].id : null
}

output "availability_zones" {
  description = "List of availability zones used"
  value       = local.azs
}

output "flow_log_group_arn" {
  description = "ARN of the VPC flow logs CloudWatch log group"
  value       = var.enable_flow_logs ? aws_cloudwatch_log_group.flow_logs[0].arn : null
}
