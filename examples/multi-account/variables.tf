variable "aws_region" {
  description = "AWS region for both accounts"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Name prefix for resources"
  type        = string
  default     = "hybrid-network"
}

variable "network_account_id" {
  description = "12-digit account ID that owns the Transit Gateway and inspection VPC"
  type        = string
  default     = "111111111111"
}

variable "workload_account_id" {
  description = "12-digit account ID that owns the spoke VPC and attaches via RAM"
  type        = string
  default     = "222222222222"
}

variable "management_assume_role_arn" {
  description = "Role ARN in the Organizations management account used to create the SCP. Null skips assume_role (same-account validate/plan)."
  type        = string
  default     = null
}

variable "network_assume_role_arn" {
  description = "Role ARN to assume in the network account. Null skips assume_role."
  type        = string
  default     = null
}

variable "workload_assume_role_arn" {
  description = "Role ARN to assume in the workload account. Null skips assume_role."
  type        = string
  default     = null
}

variable "inspection_vpc_cidr" {
  description = "CIDR for the inspection VPC in the network account"
  type        = string
  default     = "10.0.0.0/24"
}

variable "workload_vpc_cidr" {
  description = "CIDR for the workload spoke VPC"
  type        = string
  default     = "10.10.0.0/24"
}

variable "reserved_nonprod_cidr" {
  description = "CIDR reserved for future nonprod spokes; dropped by the firewall even before that VPC exists"
  type        = string
  default     = "10.20.0.0/24"
}

variable "az_count" {
  description = "Number of AZs"
  type        = number
  default     = 2
}

variable "scp_target_id" {
  description = "Organizations root, OU, or account ID to attach the SCP to. Null creates the policy without attaching it (required for terraform validate / sandbox apply without Organizations admin)."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
