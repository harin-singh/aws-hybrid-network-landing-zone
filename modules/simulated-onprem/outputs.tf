output "vpc_id" {
  description = "ID of the simulated on-premises VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "private_subnet_id" {
  description = "ID of the private subnet"
  value       = aws_subnet.private.id
}

output "router_public_ip" {
  description = "Public IP of the VPN router (for customer gateway)"
  value       = aws_eip.router.public_ip
}

output "router_private_ip" {
  description = "Private IP of the VPN router"
  value       = aws_network_interface.router_private.private_ip
}

output "router_instance_id" {
  description = "Instance ID of the router"
  value       = aws_instance.router.id
}

output "test_instance_id" {
  description = "Instance ID of the test instance"
  value       = var.create_test_instance ? aws_instance.test[0].id : null
}

output "test_instance_private_ip" {
  description = "Private IP of the test instance"
  value       = var.create_test_instance ? aws_instance.test[0].private_ip : null
}

output "advertised_cidr" {
  description = "CIDR being advertised via BGP"
  value       = var.onprem_cidr_to_advertise
}
