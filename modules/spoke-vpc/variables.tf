variable "name" {
  description = "Name prefix for VPC and related resources"
  type        = string
}

variable "environment" {
  description = "Environment name (prod, nonprod, shared-services)"
  type        = string

  validation {
    condition     = contains(["prod", "nonprod", "shared-services", "inspection"], var.environment)
    error_message = "Environment must be prod, nonprod, shared-services, or inspection."
  }
}

variable "region" {
  description = "AWS region for VPC endpoints"
  type        = string
}

#------------------------------------------------------------------------------
# CIDR Configuration
#------------------------------------------------------------------------------

variable "cidr_block" {
  description = "VPC CIDR block (required if not using IPAM)"
  type        = string
  default     = null
}

variable "ipam_pool_id" {
  description = "IPAM pool ID for CIDR allocation"
  type        = string
  default     = null
}

variable "ipam_netmask_length" {
  description = "Netmask length when using IPAM"
  type        = number
  default     = 24
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets (if null, calculated from VPC CIDR)"
  type        = list(string)
  default     = null
}

variable "private_subnet_newbits" {
  description = "Number of additional bits for private subnet calculation"
  type        = number
  default     = 4
}

variable "tgw_subnet_cidrs" {
  description = "List of CIDR blocks for TGW attachment subnets"
  type        = list(string)
  default     = null
}

variable "tgw_subnet_newbits" {
  description = "Number of additional bits for TGW subnet calculation"
  type        = number
  default     = 8
}

#------------------------------------------------------------------------------
# Availability Zones
#------------------------------------------------------------------------------

variable "availability_zones" {
  description = "List of AZs to use (if null, auto-selects based on az_count)"
  type        = list(string)
  default     = null
}

variable "az_count" {
  description = "Number of AZs to use when availability_zones is null"
  type        = number
  default     = 2

  validation {
    condition     = var.az_count >= 1 && var.az_count <= 3
    error_message = "AZ count must be between 1 and 3."
  }
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
# VPC Endpoints
#------------------------------------------------------------------------------

variable "enable_ssm_endpoints" {
  description = "Create VPC endpoints for SSM, SSM Messages, and EC2 Messages"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# Flow Logs
#------------------------------------------------------------------------------

variable "enable_flow_logs" {
  description = "Enable VPC flow logs"
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
}

variable "flow_logs_kms_key_id" {
  description = "KMS key ID for encrypting flow logs"
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
