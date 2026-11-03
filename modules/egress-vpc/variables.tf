variable "name" {
  description = "Name prefix for egress VPC and related resources"
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
