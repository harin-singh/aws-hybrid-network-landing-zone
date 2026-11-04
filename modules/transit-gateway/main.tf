#------------------------------------------------------------------------------
# Transit Gateway - Hub for AWS hybrid network landing zone
#
# Implements segmented routing with separate route tables for:
# - Production workloads
# - Non-production workloads  
# - Shared services (DNS, monitoring, etc.)
# - Inspection (centralized Network Firewall)
# - On-premises connectivity (VPN/Direct Connect)
#
# Traffic flow: All inter-VPC and egress traffic routes through inspection VPC.
# Segmentation: Prod and non-prod cannot communicate directly.
#------------------------------------------------------------------------------

# checkov:skip=CKV_AWS_331: Auto-accept is required for RAM-shared attachments from org accounts
resource "aws_ec2_transit_gateway" "this" {
  description                     = var.description
  amazon_side_asn                 = var.amazon_side_asn
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  auto_accept_shared_attachments  = var.auto_accept_shared_attachments ? "enable" : "disable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"
  multicast_support               = var.enable_multicast ? "enable" : "disable"

  tags = merge(var.tags, {
    Name = var.name
  })
}

#------------------------------------------------------------------------------
# Route Tables - Segmented by environment/function
#------------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_route_table" "prod" {
  count = var.create_route_tables ? 1 : 0

  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(var.tags, {
    Name        = "${var.name}-prod"
    Environment = "prod"
    Purpose     = "Production workload routing"
  })
}

resource "aws_ec2_transit_gateway_route_table" "nonprod" {
  count = var.create_route_tables ? 1 : 0

  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(var.tags, {
    Name        = "${var.name}-nonprod"
    Environment = "nonprod"
    Purpose     = "Non-production workload routing"
  })
}

resource "aws_ec2_transit_gateway_route_table" "shared_services" {
  count = var.create_route_tables ? 1 : 0

  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(var.tags, {
    Name    = "${var.name}-shared-services"
    Purpose = "Shared services routing (DNS, monitoring)"
  })
}

resource "aws_ec2_transit_gateway_route_table" "inspection" {
  count = var.create_route_tables ? 1 : 0

  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(var.tags, {
    Name    = "${var.name}-inspection"
    Purpose = "Inspection VPC routing (Network Firewall)"
  })
}

resource "aws_ec2_transit_gateway_route_table" "onprem" {
  count = var.create_route_tables ? 1 : 0

  transit_gateway_id = aws_ec2_transit_gateway.this.id

  tags = merge(var.tags, {
    Name    = "${var.name}-onprem"
    Purpose = "On-premises connectivity (VPN/Direct Connect)"
  })
}

locals {
  route_table_ids = var.create_route_tables ? {
    prod            = aws_ec2_transit_gateway_route_table.prod[0].id
    nonprod         = aws_ec2_transit_gateway_route_table.nonprod[0].id
    shared_services = aws_ec2_transit_gateway_route_table.shared_services[0].id
    inspection      = aws_ec2_transit_gateway_route_table.inspection[0].id
    onprem          = aws_ec2_transit_gateway_route_table.onprem[0].id
  } : {}

  blackhole_routes = var.create_route_tables ? {
    for item in flatten([
      for rt_key, cidrs in var.blackhole_routes : [
        for cidr in cidrs : {
          key    = "${rt_key}:${cidr}"
          rt_key = rt_key
          cidr   = cidr
        }
      ]
    ]) : item.key => item
  } : {}
}

resource "aws_ec2_transit_gateway_route" "blackhole" {
  for_each = local.blackhole_routes

  destination_cidr_block         = each.value.cidr
  blackhole                      = true
  transit_gateway_route_table_id = local.route_table_ids[each.value.rt_key]
}

#------------------------------------------------------------------------------
# Flow Logs - Visibility into TGW traffic patterns
#------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  create_log_kms    = var.enable_flow_logs && var.flow_logs_kms_key_id == null && var.flow_logs_destination_type == "cloud-watch-logs"
  flow_logs_kms_arn = var.flow_logs_kms_key_id != null ? var.flow_logs_kms_key_id : (local.create_log_kms ? aws_kms_key.logs[0].arn : null)
}

data "aws_iam_policy_document" "logs_kms" {
  count = local.create_log_kms ? 1 : 0

  statement {
    sid    = "EnableRoot"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.region}.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:*"]
    }
  }
}

resource "aws_kms_key" "logs" {
  count = local.create_log_kms ? 1 : 0

  description             = "${var.name} Transit Gateway flow log encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.logs_kms[0].json

  tags = var.tags
}

resource "aws_kms_alias" "logs" {
  count = local.create_log_kms ? 1 : 0

  name          = "alias/${var.name}-tgw-logs"
  target_key_id = aws_kms_key.logs[0].id
}

resource "aws_cloudwatch_log_group" "tgw_flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/aws/tgw/${var.name}/flow-logs"
  retention_in_days = var.flow_logs_retention_days
  kms_key_id        = local.flow_logs_kms_arn

  tags = var.tags
}

resource "aws_flow_log" "tgw" {
  count = var.enable_flow_logs ? 1 : 0

  traffic_type             = "ALL"
  transit_gateway_id       = aws_ec2_transit_gateway.this.id
  log_destination_type     = var.flow_logs_destination_type
  log_destination          = var.flow_logs_destination_type == "cloud-watch-logs" ? aws_cloudwatch_log_group.tgw_flow_logs[0].arn : var.flow_logs_s3_bucket_arn
  max_aggregation_interval = var.flow_logs_aggregation_interval
  iam_role_arn             = var.flow_logs_destination_type == "cloud-watch-logs" ? aws_iam_role.flow_logs[0].arn : null

  tags = merge(var.tags, {
    Name = "${var.name}-flow-logs"
  })
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs && var.flow_logs_destination_type == "cloud-watch-logs" ? 1 : 0

  name = "${var.name}-tgw-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "flow_logs" {
  count = var.enable_flow_logs && var.flow_logs_destination_type == "cloud-watch-logs" ? 1 : 0

  name = "${var.name}-tgw-flow-logs-policy"
  role = aws_iam_role.flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Effect   = "Allow"
      Resource = "${aws_cloudwatch_log_group.tgw_flow_logs[0].arn}:*"
    }]
  })
}

#------------------------------------------------------------------------------
# Resource Access Manager Share - Multi-account support
#------------------------------------------------------------------------------

resource "aws_ram_resource_share" "tgw" {
  count = var.share_tgw && length(var.ram_principals) > 0 ? 1 : 0

  name                      = "${var.name}-tgw-share"
  allow_external_principals = var.ram_allow_external_principals

  tags = merge(var.tags, {
    Name = "${var.name}-tgw-share"
  })
}

resource "aws_ram_resource_association" "tgw" {
  count = var.share_tgw && length(var.ram_principals) > 0 ? 1 : 0

  resource_arn       = aws_ec2_transit_gateway.this.arn
  resource_share_arn = aws_ram_resource_share.tgw[0].arn
}

resource "aws_ram_principal_association" "tgw" {
  for_each = var.share_tgw ? toset(var.ram_principals) : toset([])

  principal          = each.value
  resource_share_arn = aws_ram_resource_share.tgw[0].arn
}
