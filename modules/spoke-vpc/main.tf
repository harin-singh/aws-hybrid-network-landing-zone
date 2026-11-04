#------------------------------------------------------------------------------
# Spoke VPC - Workload VPC attached to Transit Gateway
#
# Design decisions:
# - No IGW: All egress goes through TGW to centralized inspection/NAT
# - Dedicated TGW attachment subnets: Small /28 subnets for attachment ENIs
# - VPC Endpoints: SSM, EC2 Messages, SSM Messages for private instance access
# - Multi-AZ: Spreads across AZs for high availability
#------------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  azs            = var.availability_zones != null ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, var.az_count)
  az_count       = length(local.azs)
  create_ipam    = var.ipam_pool_id != null
  create_log_kms = var.enable_flow_logs && var.flow_logs_kms_key_id == null
  log_kms_arn    = var.flow_logs_kms_key_id != null ? var.flow_logs_kms_key_id : (local.create_log_kms ? aws_kms_key.logs[0].arn : null)
}

#------------------------------------------------------------------------------
# VPC
#------------------------------------------------------------------------------

resource "aws_vpc" "this" {
  cidr_block           = local.create_ipam ? null : var.cidr_block
  ipv4_ipam_pool_id    = var.ipam_pool_id
  ipv4_netmask_length  = local.create_ipam ? var.ipam_netmask_length : null
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name        = var.name
    Environment = var.environment
  })
}

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-default-sg-locked"
  })
}

#------------------------------------------------------------------------------
# Subnets - Private workload and TGW attachment
#------------------------------------------------------------------------------

resource "aws_subnet" "private" {
  count = local.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.private_subnet_cidrs != null ? var.private_subnet_cidrs[count.index] : cidrsubnet(aws_vpc.this.cidr_block, var.private_subnet_newbits, count.index)
  availability_zone = local.azs[count.index]

  tags = merge(var.tags, {
    Name        = "${var.name}-private-${local.azs[count.index]}"
    Tier        = "private"
    Environment = var.environment
  })
}

resource "aws_subnet" "tgw_attachment" {
  count = local.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = var.tgw_subnet_cidrs != null ? var.tgw_subnet_cidrs[count.index] : cidrsubnet(aws_vpc.this.cidr_block, var.tgw_subnet_newbits, count.index + 100)
  availability_zone = local.azs[count.index]

  tags = merge(var.tags, {
    Name        = "${var.name}-tgw-${local.azs[count.index]}"
    Tier        = "tgw-attachment"
    Environment = var.environment
  })
}

#------------------------------------------------------------------------------
# Route Tables
#------------------------------------------------------------------------------

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name        = "${var.name}-private"
    Environment = var.environment
  })
}

resource "aws_route_table_association" "private" {
  count = local.az_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table" "tgw_attachment" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name        = "${var.name}-tgw-attachment"
    Environment = var.environment
  })
}

resource "aws_route_table_association" "tgw_attachment" {
  count = local.az_count

  subnet_id      = aws_subnet.tgw_attachment[count.index].id
  route_table_id = aws_route_table.tgw_attachment.id
}

resource "aws_route" "default_to_tgw" {
  count = var.transit_gateway_id != null ? 1 : 0

  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = var.transit_gateway_id
}

#------------------------------------------------------------------------------
# Transit Gateway Attachment
#------------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  count = var.transit_gateway_id != null ? 1 : 0

  transit_gateway_id = var.transit_gateway_id
  vpc_id             = aws_vpc.this.id
  subnet_ids         = aws_subnet.tgw_attachment[*].id

  dns_support                                     = "enable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(var.tags, {
    Name        = "${var.name}-tgw-attachment"
    Environment = var.environment
  })
}

resource "aws_ec2_transit_gateway_route_table_association" "this" {
  count = var.transit_gateway_id != null && var.tgw_route_table_id != null ? 1 : 0

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this[0].id
  transit_gateway_route_table_id = var.tgw_route_table_id
}

resource "aws_ec2_transit_gateway_route_table_propagation" "this" {
  for_each = var.transit_gateway_id != null ? toset(var.tgw_propagation_route_table_ids) : toset([])

  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.this[0].id
  transit_gateway_route_table_id = each.value
}

#------------------------------------------------------------------------------
# VPC Endpoints - SSM for private instance access
#------------------------------------------------------------------------------

resource "aws_security_group" "vpc_endpoints" {
  count = var.enable_ssm_endpoints ? 1 : 0

  name        = "${var.name}-vpc-endpoints"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.this.cidr_block]
  }

  egress {
    description = "HTTPS to VPC endpoints and AWS APIs"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-vpc-endpoints"
  })
}

resource "aws_vpc_endpoint" "ssm" {
  count = var.enable_ssm_endpoints ? 1 : 0

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.name}-ssm-endpoint"
  })
}

resource "aws_vpc_endpoint" "ssm_messages" {
  count = var.enable_ssm_endpoints ? 1 : 0

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.name}-ssmmessages-endpoint"
  })
}

resource "aws_vpc_endpoint" "ec2_messages" {
  count = var.enable_ssm_endpoints ? 1 : 0

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints[0].id]
  private_dns_enabled = true

  tags = merge(var.tags, {
    Name = "${var.name}-ec2messages-endpoint"
  })
}

#------------------------------------------------------------------------------
# VPC Flow Logs
#------------------------------------------------------------------------------

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

  description             = "${var.name} VPC flow log encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.logs_kms[0].json

  tags = var.tags
}

resource "aws_kms_alias" "logs" {
  count = local.create_log_kms ? 1 : 0

  name          = "alias/${var.name}-vpc-logs"
  target_key_id = aws_kms_key.logs[0].id
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/aws/vpc/${var.name}/flow-logs"
  retention_in_days = var.flow_logs_retention_days
  kms_key_id        = local.log_kms_arn

  tags = var.tags
}

resource "aws_iam_role" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.name}-vpc-flow-logs-role"

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
  count = var.enable_flow_logs ? 1 : 0

  name = "${var.name}-vpc-flow-logs-policy"
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
      Resource = "${aws_cloudwatch_log_group.flow_logs[0].arn}:*"
    }]
  })
}

resource "aws_flow_log" "this" {
  count = var.enable_flow_logs ? 1 : 0

  vpc_id               = aws_vpc.this.id
  traffic_type         = "ALL"
  log_destination_type = "cloud-watch-logs"
  log_destination      = aws_cloudwatch_log_group.flow_logs[0].arn
  iam_role_arn         = aws_iam_role.flow_logs[0].arn

  tags = merge(var.tags, {
    Name = "${var.name}-flow-logs"
  })
}
