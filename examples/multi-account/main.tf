#------------------------------------------------------------------------------
# Multi-account example
#
# Network account: Transit Gateway, inspection VPC, RAM share.
# Workload account: spoke VPC attached to the shared TGW.
# Management account: SCP that denies TGW/route-table mutation outside the
# network account. The SCP is created always and attached only when
# scp_target_id is set.
#
# Apply from a principal that can assume the three roles, or omit the
# assume_role ARNs to validate/plan against a single sandbox account.
#------------------------------------------------------------------------------

module "transit_gateway" {
  source = "../../modules/transit-gateway"

  providers = {
    aws = aws.network
  }

  name            = "${var.project_name}-tgw"
  amazon_side_asn = 64512

  share_tgw      = true
  ram_principals = [var.workload_account_id]

  blackhole_routes = {
    prod = [
      var.reserved_nonprod_cidr,
    ]
  }

  enable_flow_logs = true

  tags = var.tags
}

module "inspection_vpc" {
  source = "../../modules/inspection-vpc"

  providers = {
    aws = aws.network
  }

  name       = "${var.project_name}-inspection"
  cidr_block = var.inspection_vpc_cidr
  az_count   = var.az_count

  enable_egress      = true
  single_nat_gateway = true

  transit_gateway_id = module.transit_gateway.transit_gateway_id
  tgw_route_table_id = module.transit_gateway.inspection_route_table_id

  prod_cidrs    = [var.workload_vpc_cidr]
  nonprod_cidrs = [var.reserved_nonprod_cidr]
  shared_cidrs  = [var.inspection_vpc_cidr]
  onprem_cidrs  = ["10.200.0.0/16"]

  enable_firewall_logs = true
  enable_flow_logs     = true

  tags = var.tags
}

module "workload_spoke" {
  source = "../../modules/spoke-vpc"

  providers = {
    aws = aws.workload
  }

  name        = "${var.project_name}-prod"
  environment = "prod"
  region      = var.aws_region
  cidr_block  = var.workload_vpc_cidr
  az_count    = var.az_count

  transit_gateway_id = module.transit_gateway.transit_gateway_id
  # Association and propagation are created by the TGW owner (network account).
  tgw_route_table_id              = null
  tgw_propagation_route_table_ids = []

  enable_ssm_endpoints = true
  enable_flow_logs     = true

  tags = var.tags

  depends_on = [module.transit_gateway]
}

resource "aws_ec2_transit_gateway_route_table_association" "workload_prod" {
  provider = aws.network

  transit_gateway_attachment_id  = module.workload_spoke.tgw_attachment_id
  transit_gateway_route_table_id = module.transit_gateway.prod_route_table_id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "workload_to_inspection" {
  provider = aws.network

  transit_gateway_attachment_id  = module.workload_spoke.tgw_attachment_id
  transit_gateway_route_table_id = module.transit_gateway.inspection_route_table_id
}

resource "aws_ec2_transit_gateway_route" "prod_default" {
  provider = aws.network

  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = module.inspection_vpc.tgw_attachment_id
  transit_gateway_route_table_id = module.transit_gateway.prod_route_table_id
}

resource "aws_ec2_transit_gateway_route" "inspection_to_workload" {
  provider = aws.network

  destination_cidr_block         = var.workload_vpc_cidr
  transit_gateway_attachment_id  = module.workload_spoke.tgw_attachment_id
  transit_gateway_route_table_id = module.transit_gateway.inspection_route_table_id
}

resource "aws_organizations_policy" "protect_network" {
  provider = aws.management

  name        = "${var.project_name}-protect-network-hub"
  description = "Deny Transit Gateway and route-table changes outside the network account"
  type        = "SERVICE_CONTROL_POLICY"
  content = templatefile("${path.module}/policies/protect-network-hub.json", {
    network_account_id = var.network_account_id
  })

  tags = var.tags
}

resource "aws_organizations_policy_attachment" "protect_network" {
  count    = var.scp_target_id != null ? 1 : 0
  provider = aws.management

  policy_id = aws_organizations_policy.protect_network.id
  target_id = var.scp_target_id
}
