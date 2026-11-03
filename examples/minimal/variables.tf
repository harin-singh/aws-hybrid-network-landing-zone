variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-west-2"
}

variable "project_name" {
  description = "Project name prefix for all resources"
  type        = string
  default     = "hybrid-minimal"
}

#------------------------------------------------------------------------------
# VPC CIDRs
#------------------------------------------------------------------------------

variable "egress_vpc_cidr" {
  description = "CIDR block for egress VPC"
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

#------------------------------------------------------------------------------
# Tags
#------------------------------------------------------------------------------

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
