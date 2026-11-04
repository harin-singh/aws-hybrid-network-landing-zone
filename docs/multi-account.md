# Multi-Account Deployment Guide

A compact, `terraform validate`-able configuration lives in [examples/multi-account](../examples/multi-account): network account (TGW + inspection + RAM share), one workload account (spoke attachment), and an Organizations SCP that denies TGW/route-table mutation outside the network account.

This page is the longer design note (IPAM, Account Factory, centralized flow logs). Placeholder OU ARNs below are examples, not live identifiers.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         AWS Organization                                     │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    Network Account (Hub)                             │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌────────────┐  │   │
│  │  │   Transit   │  │ Inspection  │  │   Shared    │  │    IPAM    │  │   │
│  │  │   Gateway   │  │    VPC      │  │  Services   │  │   (Opt)    │  │   │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └────────────┘  │   │
│  │         │                │                │                          │   │
│  │         └────────────────┴────────────────┘                          │   │
│  │                          │                                           │   │
│  │                    RAM Share                                         │   │
│  └──────────────────────────┼───────────────────────────────────────────┘   │
│                             │                                               │
│         ┌───────────────────┼───────────────────┐                          │
│         │                   │                   │                          │
│  ┌──────┴──────┐     ┌──────┴──────┐     ┌──────┴──────┐                   │
│  │  Prod OU    │     │ Nonprod OU  │     │  Sandbox OU │                   │
│  │             │     │             │     │             │                   │
│  │ ┌─────────┐ │     │ ┌─────────┐ │     │ ┌─────────┐ │                   │
│  │ │ App 1   │ │     │ │ Dev 1   │ │     │ │ Test 1  │ │                   │
│  │ │ Account │ │     │ │ Account │ │     │ │ Account │ │                   │
│  │ └─────────┘ │     │ └─────────┘ │     │ └─────────┘ │                   │
│  │ ┌─────────┐ │     │ ┌─────────┐ │     │             │                   │
│  │ │ App 2   │ │     │ │ Dev 2   │ │     │             │                   │
│  │ │ Account │ │     │ │ Account │ │     │             │                   │
│  │ └─────────┘ │     │ └─────────┘ │     │             │                   │
│  └─────────────┘     └─────────────┘     └─────────────┘                   │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Account Structure

| Account | Purpose | Resources |
|---------|---------|-----------|
| **Network** | Centralized networking | TGW, Inspection VPC, Shared Services, DX/VPN |
| **Security** | Security tooling | GuardDuty, Security Hub, Config aggregation |
| **Log Archive** | Centralized logging | Flow logs, firewall logs, CloudTrail |
| **Workload (many)** | Applications | Spoke VPCs attached to shared TGW |

## Step 1: Network Account Setup

Deploy the core infrastructure in the network account:

```hcl
# network-account/main.tf

provider "aws" {
  region = "us-west-2"
  # Assume role in network account
}

module "transit_gateway" {
  source = "../../modules/transit-gateway"

  name            = "enterprise-tgw"
  amazon_side_asn = 64512

  # Share with the entire organization
  share_tgw = true
  ram_principals = [
    data.aws_organizations_organization.this.arn
  ]

  # Or share with specific OUs
  # ram_principals = [
  #   "arn:aws:organizations::${local.org_master}:ou/${local.org_id}/ou-xxxx-prod",
  #   "arn:aws:organizations::${local.org_master}:ou/${local.org_id}/ou-xxxx-nonprod",
  # ]
}

module "inspection_vpc" {
  source = "../../modules/inspection-vpc"

  name       = "inspection"
  cidr_block = "10.0.0.0/24"
  # ...
}

module "shared_services_vpc" {
  source = "../../modules/shared-services-vpc"

  name       = "shared-services"
  cidr_block = "10.1.0.0/24"

  # Share resolver rules with all accounts
  share_resolver_rules = true
  ram_principals = [
    data.aws_organizations_organization.this.arn
  ]
  # ...
}

# Output the TGW ID for workload accounts
output "transit_gateway_id" {
  value = module.transit_gateway.transit_gateway_id
}

output "route_table_ids" {
  value = module.transit_gateway.route_table_ids
}
```

## Step 2: Workload Account Setup

In each workload account, reference the shared TGW:

```hcl
# workload-account/main.tf

provider "aws" {
  region = "us-west-2"
  # Assume role in workload account
}

# Find the shared Transit Gateway
data "aws_ec2_transit_gateway" "shared" {
  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "owner-id"
    values = [var.network_account_id]
  }
}

# Accept the RAM share (if not using auto-accept)
resource "aws_ram_resource_share_accepter" "tgw" {
  share_arn = var.tgw_ram_share_arn
}

# Deploy spoke VPC
module "spoke_vpc" {
  source = "../../modules/spoke-vpc"

  name        = "app-prod"
  environment = "prod"
  region      = "us-west-2"
  cidr_block  = "10.100.0.0/24"

  transit_gateway_id = data.aws_ec2_transit_gateway.shared.id

  # Route table ID from network account (via SSM Parameter or Terraform remote state)
  tgw_route_table_id = var.prod_route_table_id

  tgw_propagation_route_table_ids = [
    var.inspection_route_table_id,
  ]
}

# Associate shared resolver rules
data "aws_route53_resolver_rules" "shared" {
  rule_type    = "FORWARD"
  share_status = "SHARED_WITH_ME"
}

resource "aws_route53_resolver_rule_association" "shared" {
  for_each = toset(data.aws_route53_resolver_rules.shared.resolver_rule_ids)

  resolver_rule_id = each.value
  vpc_id           = module.spoke_vpc.vpc_id
}
```

## Step 3: Cross-Account Route Tables

The network account owns the route tables. Use a centralized Terraform workspace or StackSets to manage routes:

```hcl
# network-account/routes.tf

# Each workload account's VPC attachment needs:
# 1. Association with its route table (prod, nonprod, etc.)
# 2. Propagation to inspection route table

# This requires the attachment ID from the workload account
# Use SSM Parameter Store or Terraform remote state to share

data "aws_ec2_transit_gateway_vpc_attachments" "workloads" {
  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "transit-gateway-id"
    values = [module.transit_gateway.transit_gateway_id]
  }
}

# Dynamic route management based on attachment tags
locals {
  attachments_by_env = {
    for att in data.aws_ec2_transit_gateway_vpc_attachments.workloads.ids :
    att => data.aws_ec2_transit_gateway_vpc_attachment.each[att].tags["Environment"]
  }
}
```

## VPC IPAM Integration

IPAM centralizes IP address management across accounts:

```hcl
# network-account/ipam.tf

resource "aws_vpc_ipam" "this" {
  operating_regions {
    region_name = "us-west-2"
  }

  tags = {
    Name = "enterprise-ipam"
  }
}

resource "aws_vpc_ipam_pool" "top_level" {
  ipam_scope_id = aws_vpc_ipam.this.private_default_scope_id
  address_family = "ipv4"

  tags = {
    Name = "enterprise-top-level"
  }
}

resource "aws_vpc_ipam_pool_cidr" "top_level" {
  ipam_pool_id = aws_vpc_ipam_pool.top_level.id
  cidr         = "10.0.0.0/8"
}

# Regional pool
resource "aws_vpc_ipam_pool" "us_west_2" {
  ipam_scope_id       = aws_vpc_ipam.this.private_default_scope_id
  address_family      = "ipv4"
  source_ipam_pool_id = aws_vpc_ipam_pool.top_level.id
  locale              = "us-west-2"

  tags = {
    Name = "us-west-2"
  }
}

resource "aws_vpc_ipam_pool_cidr" "us_west_2" {
  ipam_pool_id   = aws_vpc_ipam_pool.us_west_2.id
  netmask_length = 12  # 10.0.0.0/12 for us-west-2
}

# Environment-specific pools
resource "aws_vpc_ipam_pool" "prod" {
  ipam_scope_id       = aws_vpc_ipam.this.private_default_scope_id
  address_family      = "ipv4"
  source_ipam_pool_id = aws_vpc_ipam_pool.us_west_2.id
  locale              = "us-west-2"

  allocation_default_netmask_length = 24
  allocation_min_netmask_length     = 24
  allocation_max_netmask_length     = 20

  tags = {
    Name        = "prod"
    Environment = "prod"
  }
}

# Share IPAM pool with organization
resource "aws_ram_resource_share" "ipam" {
  name                      = "ipam-pools"
  allow_external_principals = false
}

resource "aws_ram_resource_association" "ipam_prod" {
  resource_arn       = aws_vpc_ipam_pool.prod.arn
  resource_share_arn = aws_ram_resource_share.ipam.arn
}

resource "aws_ram_principal_association" "ipam_org" {
  principal          = data.aws_organizations_organization.this.arn
  resource_share_arn = aws_ram_resource_share.ipam.arn
}
```

### Using IPAM in Workload Accounts

```hcl
# workload-account/main.tf

data "aws_vpc_ipam_pool" "prod" {
  filter {
    name   = "tag:Environment"
    values = ["prod"]
  }
}

module "spoke_vpc" {
  source = "../../modules/spoke-vpc"

  name        = "app-prod"
  environment = "prod"
  region      = "us-west-2"

  # Use IPAM instead of explicit CIDR
  ipam_pool_id        = data.aws_vpc_ipam_pool.prod.id
  ipam_netmask_length = 24

  # ...
}
```

## Service Control Policies

Enforce networking requirements with SCPs:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyVPCWithoutIPAM",
      "Effect": "Deny",
      "Action": "ec2:CreateVpc",
      "Resource": "*",
      "Condition": {
        "Null": {
          "ec2:Ipv4IpamPoolId": "true"
        }
      }
    },
    {
      "Sid": "DenyIGW",
      "Effect": "Deny",
      "Action": [
        "ec2:CreateInternetGateway",
        "ec2:AttachInternetGateway"
      ],
      "Resource": "*"
    },
    {
      "Sid": "DenyDirectTGWAttachment",
      "Effect": "Deny",
      "Action": "ec2:CreateTransitGatewayVpcAttachment",
      "Resource": "*",
      "Condition": {
        "StringNotEquals": {
          "aws:PrincipalOrgID": "${aws:PrincipalOrgID}"
        }
      }
    }
  ]
}
```

## Automation with Account Factory

Use AWS Control Tower Account Factory or a custom solution:

```hcl
# account-factory/spoke-baseline.tf

module "spoke_vpc" {
  source = "../../modules/spoke-vpc"

  providers = {
    aws = aws.workload
  }

  name        = var.account_name
  environment = var.environment
  region      = var.region

  ipam_pool_id        = local.ipam_pools[var.environment]
  ipam_netmask_length = 24

  transit_gateway_id = local.shared_tgw_id
  tgw_route_table_id = local.route_tables[var.environment]

  tgw_propagation_route_table_ids = [
    local.route_tables["inspection"],
  ]
}

# Auto-associate resolver rules
resource "aws_route53_resolver_rule_association" "shared" {
  for_each = local.shared_resolver_rules

  provider = aws.workload

  resolver_rule_id = each.value
  vpc_id           = module.spoke_vpc.vpc_id
}
```

## Monitoring Across Accounts

Centralize network monitoring:

```hcl
# log-archive-account/flow-logs.tf

# S3 bucket for cross-account flow logs
resource "aws_s3_bucket" "flow_logs" {
  bucket = "enterprise-vpc-flow-logs"
}

resource "aws_s3_bucket_policy" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.flow_logs.arn}/*"
        Condition = {
          StringEquals = {
            "aws:SourceOrgID" = data.aws_organizations_organization.this.id
          }
        }
      }
    ]
  })
}
```

Each workload account publishes flow logs to the central bucket:

```hcl
# workload-account/monitoring.tf

resource "aws_flow_log" "central" {
  vpc_id               = module.spoke_vpc.vpc_id
  traffic_type         = "ALL"
  log_destination_type = "s3"
  log_destination      = "arn:aws:s3:::enterprise-vpc-flow-logs"

  destination_options {
    file_format = "parquet"
  }
}
```
