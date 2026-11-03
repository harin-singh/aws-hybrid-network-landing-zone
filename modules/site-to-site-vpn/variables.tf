variable "name" {
  description = "Name prefix for VPN resources"
  type        = string
}

#------------------------------------------------------------------------------
# Transit Gateway
#------------------------------------------------------------------------------

variable "transit_gateway_id" {
  description = "Transit Gateway ID for VPN attachment"
  type        = string
}

variable "tgw_route_table_id" {
  description = "TGW route table ID to associate the VPN attachment with"
  type        = string
  default     = null
}

variable "tgw_propagation_route_table_ids" {
  description = "List of TGW route table IDs to propagate VPN routes to"
  type        = list(string)
  default     = []
}

#------------------------------------------------------------------------------
# Customer Gateway Configuration
#------------------------------------------------------------------------------

variable "customer_gateway_ip" {
  description = "Public IP address of the customer gateway device"
  type        = string
}

variable "customer_gateway_bgp_asn" {
  description = "BGP ASN of the customer gateway (on-premises router)"
  type        = number
  default     = 65000

  validation {
    condition     = (var.customer_gateway_bgp_asn >= 1 && var.customer_gateway_bgp_asn <= 4294967295)
    error_message = "Customer gateway BGP ASN must be a valid ASN (1-4294967295)."
  }
}

variable "customer_gateway_device_name" {
  description = "Descriptive name for the customer gateway device"
  type        = string
  default     = null
}

#------------------------------------------------------------------------------
# VPN Tunnel Configuration
#------------------------------------------------------------------------------

variable "enable_acceleration" {
  description = "Enable VPN acceleration (uses AWS Global Accelerator)"
  type        = bool
  default     = false
}

variable "tunnel1_inside_cidr" {
  description = "Inside CIDR for tunnel 1 (must be /30 from 169.254.0.0/16)"
  type        = string
  default     = null
}

variable "tunnel2_inside_cidr" {
  description = "Inside CIDR for tunnel 2 (must be /30 from 169.254.0.0/16)"
  type        = string
  default     = null
}

variable "tunnel1_psk" {
  description = "Pre-shared key for tunnel 1 (if null, AWS generates one)"
  type        = string
  default     = null
  sensitive   = true
}

variable "tunnel2_psk" {
  description = "Pre-shared key for tunnel 2 (if null, AWS generates one)"
  type        = string
  default     = null
  sensitive   = true
}

#------------------------------------------------------------------------------
# IPsec/IKE Configuration
#------------------------------------------------------------------------------

variable "tunnel_ike_versions" {
  description = "IKE versions for tunnels"
  type        = list(string)
  default     = ["ikev2"]
}

variable "tunnel_phase1_dh_groups" {
  description = "Phase 1 DH groups"
  type        = list(number)
  default     = [20, 21]
}

variable "tunnel_phase1_encryption" {
  description = "Phase 1 encryption algorithms"
  type        = list(string)
  default     = ["AES256-GCM-16"]
}

variable "tunnel_phase1_integrity" {
  description = "Phase 1 integrity algorithms (ignored for GCM encryption)"
  type        = list(string)
  default     = ["SHA2-256"]
}

variable "tunnel_phase2_dh_groups" {
  description = "Phase 2 DH groups"
  type        = list(number)
  default     = [20, 21]
}

variable "tunnel_phase2_encryption" {
  description = "Phase 2 encryption algorithms"
  type        = list(string)
  default     = ["AES256-GCM-16"]
}

variable "tunnel_phase2_integrity" {
  description = "Phase 2 integrity algorithms (ignored for GCM encryption)"
  type        = list(string)
  default     = ["SHA2-256"]
}

variable "tunnel_startup_action" {
  description = "Startup action for tunnels: add (on-demand) or start (always up)"
  type        = string
  default     = "add"

  validation {
    condition     = contains(["add", "start"], var.tunnel_startup_action)
    error_message = "Startup action must be 'add' or 'start'."
  }
}

variable "tunnel_dpd_timeout_action" {
  description = "DPD timeout action: clear, none, or restart"
  type        = string
  default     = "restart"

  validation {
    condition     = contains(["clear", "none", "restart"], var.tunnel_dpd_timeout_action)
    error_message = "DPD timeout action must be 'clear', 'none', or 'restart'."
  }
}

#------------------------------------------------------------------------------
# Static Routes
#------------------------------------------------------------------------------

variable "static_routes_to_onprem" {
  description = "Map of TGW route table ID to CIDR for static routes to on-prem"
  type        = map(string)
  default     = {}
}

#------------------------------------------------------------------------------
# Tags
#------------------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
