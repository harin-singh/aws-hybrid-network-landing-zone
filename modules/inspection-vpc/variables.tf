variable "name" {
  description = "Name prefix for inspection VPC and related resources"
  type        = string
}

variable "cidr_block" {
  description = "VPC CIDR block"
  type        = string
}

variable "availability_zones" {
  description = "List of AZs to use"
  type        = list(string)
  default     = null
}

variable "az_count" {
  description = "Number of AZs to use when availability_zones is null"
  type        = number
  default     = 2
}

#------------------------------------------------------------------------------
# Egress Configuration
#------------------------------------------------------------------------------

variable "enable_egress" {
  description = "Enable centralized egress (NAT Gateway and IGW)"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway instead of one per AZ (cost savings)"
  type        = bool
  default     = false
}

#------------------------------------------------------------------------------
# Transit Gateway
#------------------------------------------------------------------------------

variable "transit_gateway_id" {
  description = "Transit Gateway ID for attachment"
  type        = string
  default     = null
}

variable "tgw_route_table_id" {
  description = "TGW route table ID to associate this VPC's attachment with"
  type        = string
  default     = null
}

variable "tgw_propagation_route_table_ids" {
  description = "List of TGW route table IDs to propagate this VPC's routes to"
  type        = list(string)
  default     = []
}

variable "spoke_cidrs_aggregate" {
  description = "Aggregate CIDR for spoke VPCs (for return routing)"
  type        = string
  default     = "10.0.0.0/8"
}

#------------------------------------------------------------------------------
# Network Firewall Rules
#------------------------------------------------------------------------------

variable "blocked_domains" {
  description = "List of domains to block"
  type        = list(string)
  default     = [".malware.example.com", ".phishing.example.net"]
}

variable "home_net_cidrs" {
  description = "CIDRs representing internal networks for firewall rules"
  type        = list(string)
  default     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
}

#------------------------------------------------------------------------------
# Logging
#------------------------------------------------------------------------------

variable "enable_firewall_logs" {
  description = "Enable Network Firewall logging"
  type        = bool
  default     = true
}

variable "enable_flow_logs" {
  description = "Enable VPC flow logs"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "kms_key_id" {
  description = "KMS key ID for log encryption"
  type        = string
  default     = null
}

#------------------------------------------------------------------------------
# Tags
#------------------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
