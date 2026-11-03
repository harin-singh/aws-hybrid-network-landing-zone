#------------------------------------------------------------------------------
# Minimal Example - Cost-Optimized AWS Hybrid Network
#
# This example deploys a simplified architecture without Network Firewall:
# - Transit Gateway with segmented routing
# - Prod and Non-prod spoke VPCs
# - Shared Services VPC with Route 53 Resolver
# - Egress VPC with NAT Gateway (single AZ)
# - NO simulated on-premises (VPN) - reduces cost significantly
# - NO Network Firewall - inspection via security groups/NACLs only
#
# Use this for:
# - Learning Transit Gateway routing concepts
# - Testing module functionality
# - Budget-conscious environments
#
# Estimated monthly cost: ~$150-200 (vs ~$730 for complete example)
#------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "aws-hybrid-network-minimal"
      Environment = "demo"
      ManagedBy   = "terraform"
      Owner       = "Harinder Singh"
    }
  }
}

#------------------------------------------------------------------------------
# Transit Gateway
#------------------------------------------------------------------------------

module "transit_gateway" {
  source = "../../modules/transit-gateway"

  name            = "${var.project_name}-tgw"
  amazon_side_asn = 64512

  enable_flow_logs = false

  tags = var.tags
}

#------------------------------------------------------------------------------
# Egress VPC - Simple NAT-only egress
#------------------------------------------------------------------------------

module "egress_vpc" {
  source = "../../modules/egress-vpc"

  name       = "${var.project_name}-egress"
  cidr_block = var.egress_vpc_cidr
  az_count   = 1

  single_nat_gateway = true

  transit_gateway_id = module.transit_gateway.transit_gateway_id
  tgw_route_table_id = module.transit_gateway.inspection_route_table_id
  tgw_propagation_route_table_ids = [
    module.transit_gateway.prod_route_table_id,
    module.transit_gateway.nonprod_route_table_id,
    module.transit_gateway.shared_services_route_table_id,
  ]

  enable_flow_logs = false

  tags = var.tags
}

#------------------------------------------------------------------------------
# Shared Services VPC - DNS only (no resolver endpoints to save cost)
#------------------------------------------------------------------------------

module "shared_services_vpc" {
  source = "../../modules/shared-services-vpc"

  name       = "${var.project_name}-shared"
  cidr_block = var.shared_services_vpc_cidr
  az_count   = 1

  transit_gateway_id = module.transit_gateway.transit_gateway_id
  tgw_route_table_id = module.transit_gateway.shared_services_route_table_id
  tgw_propagation_route_table_ids = [
    module.transit_gateway.prod_route_table_id,
    module.transit_gateway.nonprod_route_table_id,
    module.transit_gateway.inspection_route_table_id,
  ]

  enable_resolver_endpoints = false
  enable_forwarding_rules   = false
  enable_private_zones      = true
  private_zone_names        = ["aws.example.internal"]

  enable_flow_logs = false

  tags = var.tags
}

#------------------------------------------------------------------------------
# Production Spoke VPC
#------------------------------------------------------------------------------

module "prod_spoke_vpc" {
  source = "../../modules/spoke-vpc"

  name        = "${var.project_name}-prod"
  environment = "prod"
  region      = var.aws_region
  cidr_block  = var.prod_vpc_cidr
  az_count    = 1

  transit_gateway_id = module.transit_gateway.transit_gateway_id
  tgw_route_table_id = module.transit_gateway.prod_route_table_id
  tgw_propagation_route_table_ids = [
    module.transit_gateway.inspection_route_table_id,
  ]

  enable_ssm_endpoints = false
  enable_flow_logs     = false

  tags = var.tags
}

#------------------------------------------------------------------------------
# Non-Production Spoke VPC
#------------------------------------------------------------------------------

module "nonprod_spoke_vpc" {
  source = "../../modules/spoke-vpc"

  name        = "${var.project_name}-nonprod"
  environment = "nonprod"
  region      = var.aws_region
  cidr_block  = var.nonprod_vpc_cidr
  az_count    = 1

  transit_gateway_id = module.transit_gateway.transit_gateway_id
  tgw_route_table_id = module.transit_gateway.nonprod_route_table_id
  tgw_propagation_route_table_ids = [
    module.transit_gateway.inspection_route_table_id,
  ]

  enable_ssm_endpoints = false
  enable_flow_logs     = false

  tags = var.tags
}

#------------------------------------------------------------------------------
# TGW Routes - Segmented routing through egress VPC
#------------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_route" "prod_default" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = module.egress_vpc.tgw_attachment_id
  transit_gateway_route_table_id = module.transit_gateway.prod_route_table_id
}

resource "aws_ec2_transit_gateway_route" "nonprod_default" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = module.egress_vpc.tgw_attachment_id
  transit_gateway_route_table_id = module.transit_gateway.nonprod_route_table_id
}

resource "aws_ec2_transit_gateway_route" "shared_services_default" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = module.egress_vpc.tgw_attachment_id
  transit_gateway_route_table_id = module.transit_gateway.shared_services_route_table_id
}

resource "aws_ec2_transit_gateway_route" "egress_to_prod" {
  destination_cidr_block         = var.prod_vpc_cidr
  transit_gateway_attachment_id  = module.prod_spoke_vpc.tgw_attachment_id
  transit_gateway_route_table_id = module.transit_gateway.inspection_route_table_id
}

resource "aws_ec2_transit_gateway_route" "egress_to_nonprod" {
  destination_cidr_block         = var.nonprod_vpc_cidr
  transit_gateway_attachment_id  = module.nonprod_spoke_vpc.tgw_attachment_id
  transit_gateway_route_table_id = module.transit_gateway.inspection_route_table_id
}

resource "aws_ec2_transit_gateway_route" "egress_to_shared" {
  destination_cidr_block         = var.shared_services_vpc_cidr
  transit_gateway_attachment_id  = module.shared_services_vpc.tgw_attachment_id
  transit_gateway_route_table_id = module.transit_gateway.inspection_route_table_id
}

resource "aws_ec2_transit_gateway_route" "prod_to_shared" {
  destination_cidr_block         = var.shared_services_vpc_cidr
  transit_gateway_attachment_id  = module.egress_vpc.tgw_attachment_id
  transit_gateway_route_table_id = module.transit_gateway.prod_route_table_id
}

resource "aws_ec2_transit_gateway_route" "nonprod_to_shared" {
  destination_cidr_block         = var.shared_services_vpc_cidr
  transit_gateway_attachment_id  = module.egress_vpc.tgw_attachment_id
  transit_gateway_route_table_id = module.transit_gateway.nonprod_route_table_id
}
