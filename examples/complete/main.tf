#------------------------------------------------------------------------------
# Complete Example - Full AWS Hybrid Network Landing Zone
#
# This example deploys the complete architecture:
# - Transit Gateway with segmented routing
# - Prod and Non-prod spoke VPCs (isolated from each other)
# - Inspection VPC with AWS Network Firewall (centralized inspection + egress)
# - Shared Services VPC with Route 53 Resolver (hybrid DNS)
# - Site-to-Site VPN with BGP
# - Simulated on-premises environment (strongSwan + FRR)
#
# Segmentation Rules:
# - Prod spoke: Can reach shared-services and on-prem, NOT non-prod
# - Non-prod spoke: Can reach shared-services, NOT prod or on-prem
# - All traffic inspected by Network Firewall
#
# WARNING: This example creates resources that incur costs. See cost table below.
# Run `make destroy` or `terraform destroy` when done testing.
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
      Project     = "aws-hybrid-network-landing-zone"
      Environment = "demo"
      ManagedBy   = "terraform"
      Owner       = "Harinder Singh"
    }
  }
}

#------------------------------------------------------------------------------
# Transit Gateway - Network Hub
#------------------------------------------------------------------------------

module "transit_gateway" {
  source = "../../modules/transit-gateway"

  name            = "${var.project_name}-tgw"
  amazon_side_asn = var.tgw_amazon_side_asn

  enable_flow_logs         = true
  flow_logs_retention_days = 30

  tags = var.tags
}

#------------------------------------------------------------------------------
# Inspection VPC - Centralized Network Firewall + Egress
#------------------------------------------------------------------------------

module "inspection_vpc" {
  source = "../../modules/inspection-vpc"

  name       = "${var.project_name}-inspection"
  cidr_block = var.inspection_vpc_cidr
  az_count   = var.az_count

  enable_egress      = true
  single_nat_gateway = var.single_nat_gateway

  transit_gateway_id              = module.transit_gateway.transit_gateway_id
  tgw_route_table_id              = module.transit_gateway.inspection_route_table_id
  tgw_propagation_route_table_ids = []

  spoke_cidrs_aggregate = "10.0.0.0/8"
  home_net_cidrs        = ["10.0.0.0/8", var.onprem_cidr]

  enable_firewall_logs = true
  enable_flow_logs     = true

  tags = var.tags
}

#------------------------------------------------------------------------------
# Shared Services VPC - Hybrid DNS
#------------------------------------------------------------------------------

module "shared_services_vpc" {
  source = "../../modules/shared-services-vpc"

  name       = "${var.project_name}-shared-services"
  cidr_block = var.shared_services_vpc_cidr
  az_count   = var.az_count

  transit_gateway_id = module.transit_gateway.transit_gateway_id
  tgw_route_table_id = module.transit_gateway.shared_services_route_table_id
  tgw_propagation_route_table_ids = [
    module.transit_gateway.prod_route_table_id,
    module.transit_gateway.nonprod_route_table_id,
    module.transit_gateway.inspection_route_table_id,
    module.transit_gateway.onprem_route_table_id,
  ]

  enable_resolver_endpoints = true
  enable_forwarding_rules   = true
  onprem_domains            = ["corp.example.internal"]
  onprem_dns_servers        = var.onprem_dns_servers

  enable_private_zones = true
  private_zone_names   = ["aws.example.internal"]

  enable_flow_logs = true

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
  az_count    = var.az_count

  transit_gateway_id = module.transit_gateway.transit_gateway_id
  tgw_route_table_id = module.transit_gateway.prod_route_table_id
  tgw_propagation_route_table_ids = [
    module.transit_gateway.inspection_route_table_id,
  ]

  enable_ssm_endpoints = true
  enable_flow_logs     = true

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
  az_count    = var.az_count

  transit_gateway_id = module.transit_gateway.transit_gateway_id
  tgw_route_table_id = module.transit_gateway.nonprod_route_table_id
  tgw_propagation_route_table_ids = [
    module.transit_gateway.inspection_route_table_id,
  ]

  enable_ssm_endpoints = true
  enable_flow_logs     = true

  tags = var.tags
}

#------------------------------------------------------------------------------
# Simulated On-Premises Environment
#------------------------------------------------------------------------------

module "simulated_onprem" {
  source = "../../modules/simulated-onprem"

  name     = "${var.project_name}-onprem"
  vpc_cidr = var.simulated_onprem_vpc_cidr

  customer_bgp_asn         = var.onprem_bgp_asn
  aws_bgp_asn              = var.tgw_amazon_side_asn
  onprem_cidr_to_advertise = var.onprem_cidr

  tunnel1_aws_endpoint  = module.site_to_site_vpn.tunnel1_address
  tunnel1_psk           = module.site_to_site_vpn.tunnel1_preshared_key
  tunnel1_cgw_inside_ip = module.site_to_site_vpn.tunnel1_cgw_inside_address
  tunnel1_aws_inside_ip = module.site_to_site_vpn.tunnel1_vgw_inside_address

  tunnel2_aws_endpoint  = module.site_to_site_vpn.tunnel2_address
  tunnel2_psk           = module.site_to_site_vpn.tunnel2_preshared_key
  tunnel2_cgw_inside_ip = module.site_to_site_vpn.tunnel2_cgw_inside_address
  tunnel2_aws_inside_ip = module.site_to_site_vpn.tunnel2_vgw_inside_address

  create_test_instance = true

  tags = var.tags
}

#------------------------------------------------------------------------------
# Site-to-Site VPN - TGW Attachment with BGP
#------------------------------------------------------------------------------

module "site_to_site_vpn" {
  source = "../../modules/site-to-site-vpn"

  name = "${var.project_name}-vpn"

  transit_gateway_id       = module.transit_gateway.transit_gateway_id
  tgw_route_table_id       = module.transit_gateway.onprem_route_table_id
  customer_gateway_ip      = module.simulated_onprem.router_public_ip
  customer_gateway_bgp_asn = var.onprem_bgp_asn

  tgw_propagation_route_table_ids = [
    module.transit_gateway.prod_route_table_id,
    module.transit_gateway.shared_services_route_table_id,
    module.transit_gateway.inspection_route_table_id,
  ]

  tags = var.tags
}

#------------------------------------------------------------------------------
# TGW Routes - Segmented Routing with Inspection
#------------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_route" "prod_default" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = module.inspection_vpc.tgw_attachment_id
  transit_gateway_route_table_id = module.transit_gateway.prod_route_table_id
}

resource "aws_ec2_transit_gateway_route" "nonprod_default" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = module.inspection_vpc.tgw_attachment_id
  transit_gateway_route_table_id = module.transit_gateway.nonprod_route_table_id
}

resource "aws_ec2_transit_gateway_route" "shared_services_default" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = module.inspection_vpc.tgw_attachment_id
  transit_gateway_route_table_id = module.transit_gateway.shared_services_route_table_id
}

resource "aws_ec2_transit_gateway_route" "onprem_default" {
  destination_cidr_block         = "0.0.0.0/0"
  transit_gateway_attachment_id  = module.inspection_vpc.tgw_attachment_id
  transit_gateway_route_table_id = module.transit_gateway.onprem_route_table_id
}

resource "aws_ec2_transit_gateway_route" "inspection_to_prod" {
  destination_cidr_block         = var.prod_vpc_cidr
  transit_gateway_attachment_id  = module.prod_spoke_vpc.tgw_attachment_id
  transit_gateway_route_table_id = module.transit_gateway.inspection_route_table_id
}

resource "aws_ec2_transit_gateway_route" "inspection_to_nonprod" {
  destination_cidr_block         = var.nonprod_vpc_cidr
  transit_gateway_attachment_id  = module.nonprod_spoke_vpc.tgw_attachment_id
  transit_gateway_route_table_id = module.transit_gateway.inspection_route_table_id
}

resource "aws_ec2_transit_gateway_route" "inspection_to_shared" {
  destination_cidr_block         = var.shared_services_vpc_cidr
  transit_gateway_attachment_id  = module.shared_services_vpc.tgw_attachment_id
  transit_gateway_route_table_id = module.transit_gateway.inspection_route_table_id
}

resource "aws_ec2_transit_gateway_route" "prod_to_shared" {
  destination_cidr_block         = var.shared_services_vpc_cidr
  transit_gateway_attachment_id  = module.inspection_vpc.tgw_attachment_id
  transit_gateway_route_table_id = module.transit_gateway.prod_route_table_id
}

resource "aws_ec2_transit_gateway_route" "nonprod_to_shared" {
  destination_cidr_block         = var.shared_services_vpc_cidr
  transit_gateway_attachment_id  = module.inspection_vpc.tgw_attachment_id
  transit_gateway_route_table_id = module.transit_gateway.nonprod_route_table_id
}

resource "aws_ec2_transit_gateway_route" "prod_to_onprem" {
  destination_cidr_block         = var.onprem_cidr
  transit_gateway_attachment_id  = module.inspection_vpc.tgw_attachment_id
  transit_gateway_route_table_id = module.transit_gateway.prod_route_table_id
}

resource "aws_ec2_transit_gateway_route" "shared_to_onprem" {
  destination_cidr_block         = var.onprem_cidr
  transit_gateway_attachment_id  = module.inspection_vpc.tgw_attachment_id
  transit_gateway_route_table_id = module.transit_gateway.shared_services_route_table_id
}

#------------------------------------------------------------------------------
# Test Instances - For connectivity validation
#------------------------------------------------------------------------------

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-kernel-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_iam_role" "test_instance" {
  name = "${var.project_name}-test-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "test_instance_ssm" {
  role       = aws_iam_role.test_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "test_instance" {
  name = "${var.project_name}-test-instance-profile"
  role = aws_iam_role.test_instance.name
}

resource "aws_security_group" "test_instance" {
  name        = "${var.project_name}-test-instance"
  description = "Security group for test instances"
  vpc_id      = module.prod_spoke_vpc.vpc_id

  ingress {
    description = "ICMP from all RFC1918"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-test-instance"
  })
}

resource "aws_security_group" "test_instance_nonprod" {
  name        = "${var.project_name}-test-instance-nonprod"
  description = "Security group for nonprod test instances"
  vpc_id      = module.nonprod_spoke_vpc.vpc_id

  ingress {
    description = "ICMP from all RFC1918"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-test-instance-nonprod"
  })
}

resource "aws_instance" "prod_test" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = module.prod_spoke_vpc.private_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.test_instance.id]
  iam_instance_profile   = aws_iam_instance_profile.test_instance.name

  tags = merge(var.tags, {
    Name = "${var.project_name}-prod-test"
  })
}

resource "aws_instance" "nonprod_test" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = module.nonprod_spoke_vpc.private_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.test_instance_nonprod.id]
  iam_instance_profile   = aws_iam_instance_profile.test_instance.name

  tags = merge(var.tags, {
    Name = "${var.project_name}-nonprod-test"
  })
}
