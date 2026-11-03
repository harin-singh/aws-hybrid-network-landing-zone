variable "name" {
  description = "Name prefix for Transit Gateway and related resources"
  type        = string
}

variable "description" {
  description = "Description for the Transit Gateway"
  type        = string
  default     = "Hub Transit Gateway for hybrid network landing zone"
}

variable "amazon_side_asn" {
  description = "Private ASN for the Amazon side of the TGW BGP sessions (64512-65534 or 4200000000-4294967294)"
  type        = number
  default     = 64512

  validation {
    condition     = (var.amazon_side_asn >= 64512 && var.amazon_side_asn <= 65534) || (var.amazon_side_asn >= 4200000000 && var.amazon_side_asn <= 4294967294)
    error_message = "Amazon side ASN must be in the private range: 64512-65534 or 4200000000-4294967294."
  }
}

variable "auto_accept_shared_attachments" {
  description = "Auto-accept attachments from accounts the TGW is shared with via RAM"
  type        = bool
  default     = true
}

variable "enable_multicast" {
  description = "Enable multicast support on the Transit Gateway"
  type        = bool
  default     = false
}

variable "create_route_tables" {
  description = "Create segmented route tables (prod, nonprod, shared-services, inspection, onprem)"
  type        = bool
  default     = true
}

#------------------------------------------------------------------------------
# Flow Logs Configuration
#------------------------------------------------------------------------------

variable "enable_flow_logs" {
  description = "Enable Transit Gateway flow logs"
  type        = bool
  default     = true
}

variable "flow_logs_destination_type" {
  description = "Destination type for flow logs: cloud-watch-logs or s3"
  type        = string
  default     = "cloud-watch-logs"

  validation {
    condition     = contains(["cloud-watch-logs", "s3"], var.flow_logs_destination_type)
    error_message = "Flow logs destination must be cloud-watch-logs or s3."
  }
}

variable "flow_logs_retention_days" {
  description = "CloudWatch log retention in days for flow logs. Checkov CKV_AWS_338 requires >= 365."
  type        = number
  default     = 365
}

variable "flow_logs_kms_key_id" {
  description = "KMS key ID for encrypting flow logs"
  type        = string
  default     = null
}

variable "flow_logs_s3_bucket_arn" {
  description = "S3 bucket ARN for flow logs when destination_type is s3"
  type        = string
  default     = null
}

variable "flow_logs_aggregation_interval" {
  description = "Maximum aggregation interval in seconds (60 or 600)"
  type        = number
  default     = 60

  validation {
    condition     = contains([60, 600], var.flow_logs_aggregation_interval)
    error_message = "Aggregation interval must be 60 or 600 seconds."
  }
}

#------------------------------------------------------------------------------
# Resource Access Manager (RAM) - Multi-account sharing
#------------------------------------------------------------------------------

variable "share_tgw" {
  description = "Share TGW via Resource Access Manager"
  type        = bool
  default     = false
}

variable "ram_principals" {
  description = "List of principals (account IDs, OU ARNs, or Organization ARN) to share TGW with"
  type        = list(string)
  default     = []
}

variable "ram_allow_external_principals" {
  description = "Allow sharing with principals outside the organization"
  type        = bool
  default     = false
}

#------------------------------------------------------------------------------
# Segmentation blackholes
#------------------------------------------------------------------------------

variable "blackhole_routes" {
  description = "Map of route table key (prod, nonprod, shared_services, inspection, onprem) to CIDRs that should be blackholed. More-specific than 0.0.0.0/0, so denied pairs are dropped at TGW even when a default route points at inspection."
  type        = map(list(string))
  default     = {}

  validation {
    condition = alltrue([
      for k in keys(var.blackhole_routes) :
      contains(["prod", "nonprod", "shared_services", "inspection", "onprem"], k)
    ])
    error_message = "blackhole_routes keys must be prod, nonprod, shared_services, inspection, or onprem."
  }
}

#------------------------------------------------------------------------------
# Tags
#------------------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
