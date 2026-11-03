variable "name" {
  description = "Name prefix for shared services VPC and related resources"
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

#------------------------------------------------------------------------------
# Route 53 Resolver Configuration
#------------------------------------------------------------------------------

variable "enable_resolver_endpoints" {
  description = "Create Route 53 Resolver inbound and outbound endpoints"
  type        = bool
  default     = true
}

variable "resolver_allowed_cidrs" {
  description = "CIDRs allowed to query the inbound resolver endpoint"
  type        = list(string)
  default     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
}

variable "enable_forwarding_rules" {
  description = "Create Route 53 Resolver forwarding rules for on-prem domains"
  type        = bool
  default     = true
}

variable "onprem_domains" {
  description = "List of on-premises domains to forward DNS queries for"
  type        = list(string)
  default     = ["corp.example.internal"]
}

variable "onprem_dns_servers" {
  description = "List of on-premises DNS server IPs"
  type        = list(string)
  default     = ["10.200.0.10", "10.200.0.11"]
}

#------------------------------------------------------------------------------
# Private Hosted Zones
#------------------------------------------------------------------------------

variable "enable_private_zones" {
  description = "Create Route 53 private hosted zones"
  type        = bool
  default     = true
}

variable "private_zone_names" {
  description = "List of private hosted zone domain names"
  type        = list(string)
  default     = ["aws.example.internal"]
}

#------------------------------------------------------------------------------
# Resource Access Manager (RAM)
#------------------------------------------------------------------------------

variable "share_resolver_rules" {
  description = "Share resolver rules via RAM"
  type        = bool
  default     = false
}

variable "ram_principals" {
  description = "List of principals to share resolver rules with"
  type        = list(string)
  default     = []
}

variable "ram_allow_external_principals" {
  description = "Allow sharing with principals outside the organization"
  type        = bool
  default     = false
}

#------------------------------------------------------------------------------
# Logging
#------------------------------------------------------------------------------

variable "enable_flow_logs" {
  description = "Enable VPC flow logs"
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "CloudWatch log retention in days. Checkov CKV_AWS_338 requires >= 365."
  type        = number
  default     = 365
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
