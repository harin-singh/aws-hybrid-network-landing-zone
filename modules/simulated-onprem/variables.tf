variable "name" {
  description = "Name prefix for simulated on-premises resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the simulated on-premises VPC"
  type        = string
  default     = "192.168.0.0/24"
}

variable "availability_zone" {
  description = "Availability zone for the VPC (if null, auto-selects first available)"
  type        = string
  default     = null
}

variable "instance_type" {
  description = "EC2 instance type for the router"
  type        = string
  default     = "t3.small"
}

#------------------------------------------------------------------------------
# BGP Configuration
#------------------------------------------------------------------------------

variable "customer_bgp_asn" {
  description = "BGP ASN for the simulated on-premises router"
  type        = number
  default     = 65000
}

variable "aws_bgp_asn" {
  description = "BGP ASN on the AWS side (Transit Gateway)"
  type        = number
  default     = 64512
}

variable "onprem_cidr_to_advertise" {
  description = "On-premises CIDR to advertise via BGP (e.g., 10.200.0.0/16)"
  type        = string
  default     = "10.200.0.0/16"
}

#------------------------------------------------------------------------------
# VPN Tunnel Configuration
# These values come from the AWS VPN connection outputs
#------------------------------------------------------------------------------

variable "tunnel1_aws_endpoint" {
  description = "AWS VPN endpoint IP for tunnel 1"
  type        = string
  default     = ""
}

variable "tunnel1_psk" {
  description = "Pre-shared key for tunnel 1. Stored in SSM SecureString and fetched at boot; never written to user_data. Null skips SSM parameter creation."
  type        = string
  default     = null
  sensitive   = true
}

variable "ipsec_peer_cidrs" {
  description = "CIDRs allowed to send IKE/NAT-T/ESP to the router (AWS VPN tunnel outside IPs as /32s). Empty means no IPsec ingress is opened."
  type        = list(string)
  default     = []
}

variable "tunnel1_cgw_inside_ip" {
  description = "Customer gateway inside IP for tunnel 1 (e.g., 169.254.10.2)"
  type        = string
  default     = "169.254.10.2"
}

variable "tunnel1_aws_inside_ip" {
  description = "AWS inside IP for tunnel 1 (e.g., 169.254.10.1)"
  type        = string
  default     = "169.254.10.1"
}

variable "tunnel2_aws_endpoint" {
  description = "AWS VPN endpoint IP for tunnel 2"
  type        = string
  default     = ""
}

variable "tunnel2_psk" {
  description = "Pre-shared key for tunnel 2. Stored in SSM SecureString and fetched at boot; never written to user_data. Null skips SSM parameter creation."
  type        = string
  default     = null
  sensitive   = true
}

variable "tunnel2_cgw_inside_ip" {
  description = "Customer gateway inside IP for tunnel 2 (e.g., 169.254.11.2)"
  type        = string
  default     = "169.254.11.2"
}

variable "tunnel2_aws_inside_ip" {
  description = "AWS inside IP for tunnel 2 (e.g., 169.254.11.1)"
  type        = string
  default     = "169.254.11.1"
}

#------------------------------------------------------------------------------
# Test Instance
#------------------------------------------------------------------------------

variable "create_test_instance" {
  description = "Create a test instance in the private subnet"
  type        = bool
  default     = true
}

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
  description = "KMS key ID for log encryption. If null, the module creates a CMK when flow logs are enabled."
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
