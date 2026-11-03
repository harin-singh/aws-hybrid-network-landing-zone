variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "hybrid-network"
}

variable "az_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 2
}

variable "single_nat_gateway" {
  description = "Use single NAT gateway to reduce costs"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# VPC CIDRs
#------------------------------------------------------------------------------

variable "inspection_vpc_cidr" {
  description = "CIDR block for inspection VPC"
  type        = string
  default     = "10.0.0.0/24"
}

variable "shared_services_vpc_cidr" {
  description = "CIDR block for shared services VPC"
  type        = string
  default     = "10.1.0.0/24"
}

variable "prod_vpc_cidr" {
  description = "CIDR block for production VPC"
  type        = string
  default     = "10.10.0.0/24"
}

variable "nonprod_vpc_cidr" {
  description = "CIDR block for non-production VPC"
  type        = string
  default     = "10.20.0.0/24"
}

variable "simulated_onprem_vpc_cidr" {
  description = "CIDR block for simulated on-premises VPC"
  type        = string
  default     = "192.168.100.0/24"
}

#------------------------------------------------------------------------------
# On-Premises Configuration
#------------------------------------------------------------------------------

variable "onprem_cidr" {
  description = "On-premises CIDR to advertise via BGP"
  type        = string
  default     = "10.200.0.0/16"
}

variable "onprem_bgp_asn" {
  description = "BGP ASN for on-premises (customer gateway)"
  type        = number
  default     = 65000
}

variable "tgw_amazon_side_asn" {
  description = "BGP ASN for Transit Gateway (AWS side)"
  type        = number
  default     = 64512
}

variable "onprem_dns_servers" {
  description = "On-premises DNS server IPs for forwarding rules"
  type        = list(string)
  default     = ["10.200.0.10", "10.200.0.11"]
}

#------------------------------------------------------------------------------
# Tags
#------------------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
