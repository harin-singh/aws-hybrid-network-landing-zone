#------------------------------------------------------------------------------
# Inspection VPC - Centralized AWS Network Firewall
#
# Design decisions:
# - Appliance mode enabled: Ensures symmetric routing through firewall
# - Separate firewall subnets: Network Firewall endpoints in dedicated subnets
# - STRICT_ORDER + stateful default drop: only explicit pass rules are allowed
# - Per-AZ public route tables: NAT return traffic stays in the same AZ
# - RFC1918 return routes to TGW: private destinations are not NATed
#------------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  azs      = var.availability_zones != null ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, var.az_count)
  az_count = length(local.azs)

  create_log_kms = (var.enable_flow_logs || var.enable_firewall_logs) && var.kms_key_id == null
  log_kms_arn    = var.kms_key_id != null ? var.kms_key_id : (local.create_log_kms ? aws_kms_key.logs[0].arn : null)

  segmentation_enabled = (
    length(var.prod_cidrs) > 0 &&
    length(var.nonprod_cidrs) > 0 &&
    length(var.shared_cidrs) > 0 &&
    length(var.onprem_cidrs) > 0
  )

  # Suricata 5 ipset syntax: one CIDR, or [cidr,cidr]
  prod_match    = length(var.prod_cidrs) == 1 ? var.prod_cidrs[0] : "[${join(",", var.prod_cidrs)}]"
  nonprod_match = length(var.nonprod_cidrs) == 1 ? var.nonprod_cidrs[0] : "[${join(",", var.nonprod_cidrs)}]"
  shared_match  = length(var.shared_cidrs) == 1 ? var.shared_cidrs[0] : "[${join(",", var.shared_cidrs)}]"
  onprem_match  = length(var.onprem_cidrs) == 1 ? var.onprem_cidrs[0] : "[${join(",", var.onprem_cidrs)}]"

  segmentation_rules = local.segmentation_enabled ? join("\n", [
    "# Denied pairs (evaluated first under STRICT_ORDER)",
    "drop ip ${local.prod_match} any -> ${local.nonprod_match} any (msg:\"Deny prod to nonprod\"; sid:1000001; rev:1;)",
    "drop ip ${local.nonprod_match} any -> ${local.prod_match} any (msg:\"Deny nonprod to prod\"; sid:1000002; rev:1;)",
    "drop ip ${local.nonprod_match} any -> ${local.onprem_match} any (msg:\"Deny nonprod to onprem\"; sid:1000003; rev:1;)",
    "drop ip ${local.onprem_match} any -> ${local.nonprod_match} any (msg:\"Deny onprem to nonprod\"; sid:1000004; rev:1;)",
    "# Allowed east-west",
    "pass ip ${local.prod_match} any -> ${local.shared_match} any (msg:\"Allow prod to shared\"; sid:2000001; rev:1;)",
    "pass ip ${local.shared_match} any -> ${local.prod_match} any (msg:\"Allow shared to prod\"; sid:2000002; rev:1;)",
    "pass ip ${local.nonprod_match} any -> ${local.shared_match} any (msg:\"Allow nonprod to shared\"; sid:2000003; rev:1;)",
    "pass ip ${local.shared_match} any -> ${local.nonprod_match} any (msg:\"Allow shared to nonprod\"; sid:2000004; rev:1;)",
    "pass ip ${local.prod_match} any -> ${local.onprem_match} any (msg:\"Allow prod to onprem\"; sid:2000005; rev:1;)",
    "pass ip ${local.onprem_match} any -> ${local.prod_match} any (msg:\"Allow onprem to prod\"; sid:2000006; rev:1;)",
    "pass ip ${local.shared_match} any -> ${local.onprem_match} any (msg:\"Allow shared to onprem\"; sid:2000007; rev:1;)",
    "pass ip ${local.onprem_match} any -> ${local.shared_match} any (msg:\"Allow onprem to shared\"; sid:2000008; rev:1;)",
  ]) : ""

  egress_rules = var.allow_inspected_egress ? "pass ip $HOME_NET any -> !$HOME_NET any (msg:\"Allow inspected egress to internet\"; sid:3000001; rev:1;)" : ""

  stateful_rules = trimspace("${local.segmentation_rules}\n${local.egress_rules}")
}

#------------------------------------------------------------------------------
# KMS - CloudWatch Logs encryption
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

  statement {
    sid    = "AllowNetworkFirewall"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["network-firewall.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]
  }
}

resource "aws_kms_key" "logs" {
  count = local.create_log_kms ? 1 : 0

  description             = "${var.name} inspection log and firewall encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.logs_kms[0].json

  tags = var.tags
}

resource "aws_kms_alias" "logs" {
  count = local.create_log_kms ? 1 : 0

  name          = "alias/${var.name}-inspection-logs"
  target_key_id = aws_kms_key.logs[0].id
}

#------------------------------------------------------------------------------
# VPC
#------------------------------------------------------------------------------

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name    = var.name
    Purpose = "inspection"
  })
}

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-default-sg-locked"
  })
}

#------------------------------------------------------------------------------
# Internet Gateway - For egress traffic after inspection
#------------------------------------------------------------------------------

resource "aws_internet_gateway" "this" {
  count = var.enable_egress ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-igw"
  })
}

#------------------------------------------------------------------------------
# Subnets
#------------------------------------------------------------------------------

resource "aws_subnet" "firewall" {
  count = local.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.cidr_block, 4, count.index)
  availability_zone = local.azs[count.index]

  tags = merge(var.tags, {
    Name = "${var.name}-firewall-${local.azs[count.index]}"
    Tier = "firewall"
  })
}

resource "aws_subnet" "tgw_attachment" {
  count = local.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.cidr_block, 4, count.index + 4)
  availability_zone = local.azs[count.index]

  tags = merge(var.tags, {
    Name = "${var.name}-tgw-${local.azs[count.index]}"
    Tier = "tgw-attachment"
  })
}

resource "aws_subnet" "public" {
  count = var.enable_egress ? local.az_count : 0

  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.cidr_block, 4, count.index + 8)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.name}-public-${local.azs[count.index]}"
    Tier = "public"
  })
}

#------------------------------------------------------------------------------
# NAT Gateways - For egress after inspection
#------------------------------------------------------------------------------

resource "aws_eip" "nat" {
  count = var.enable_egress ? (var.single_nat_gateway ? 1 : local.az_count) : 0

  domain = "vpc"

  tags = merge(var.tags, {
    Name = var.single_nat_gateway ? "${var.name}-nat-eip" : "${var.name}-nat-eip-${local.azs[count.index]}"
  })
}

resource "aws_nat_gateway" "this" {
  count = var.enable_egress ? (var.single_nat_gateway ? 1 : local.az_count) : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = merge(var.tags, {
    Name = var.single_nat_gateway ? "${var.name}-nat" : "${var.name}-nat-${local.azs[count.index]}"
  })

  depends_on = [aws_internet_gateway.this]
}

#------------------------------------------------------------------------------
# AWS Network Firewall - default drop, explicit allow
#------------------------------------------------------------------------------

resource "aws_networkfirewall_rule_group" "segmentation" {
  capacity = 100
  name     = "${var.name}-segmentation"
  type     = "STATEFUL"

  encryption_configuration {
    type   = local.log_kms_arn != null ? "CUSTOMER_KMS" : "AWS_OWNED_KMS_KEY"
    key_id = local.log_kms_arn
  }

  rule_group {
    rule_variables {
      ip_sets {
        key = "HOME_NET"
        ip_set {
          definition = var.home_net_cidrs
        }
      }
    }

    rules_source {
      rules_string = local.stateful_rules != "" ? local.stateful_rules : "pass ip 127.0.0.1 1 -> 127.0.0.1 1 (msg:\"No-op placeholder; default drop applies\"; sid:1; rev:1;)"
    }

    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }
  }

  tags = var.tags
}

resource "aws_networkfirewall_rule_group" "domain_filter" {
  capacity = 100
  name     = "${var.name}-domain-filter"
  type     = "STATEFUL"

  encryption_configuration {
    type   = local.log_kms_arn != null ? "CUSTOMER_KMS" : "AWS_OWNED_KMS_KEY"
    key_id = local.log_kms_arn
  }

  rule_group {
    rules_source {
      rules_source_list {
        generated_rules_type = "DENYLIST"
        target_types         = ["HTTP_HOST", "TLS_SNI"]
        targets              = var.blocked_domains
      }
    }

    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }
  }

  tags = var.tags
}

resource "aws_networkfirewall_firewall_policy" "this" {
  name = "${var.name}-policy"

  encryption_configuration {
    type   = local.log_kms_arn != null ? "CUSTOMER_KMS" : "AWS_OWNED_KMS_KEY"
    key_id = local.log_kms_arn
  }

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]
    stateful_default_actions           = ["aws:drop_established"]

    stateful_engine_options {
      rule_order = "STRICT_ORDER"
    }

    stateful_rule_group_reference {
      priority     = 100
      resource_arn = aws_networkfirewall_rule_group.segmentation.arn
    }

    stateful_rule_group_reference {
      priority     = 200
      resource_arn = aws_networkfirewall_rule_group.domain_filter.arn
    }
  }

  tags = var.tags
}

# checkov:skip=CKV_AWS_344: Delete protection would block terraform destroy of this lab stack
resource "aws_networkfirewall_firewall" "this" {
  name                = var.name
  firewall_policy_arn = aws_networkfirewall_firewall_policy.this.arn
  vpc_id              = aws_vpc.this.id

  encryption_configuration {
    type   = local.log_kms_arn != null ? "CUSTOMER_KMS" : "AWS_OWNED_KMS_KEY"
    key_id = local.log_kms_arn
  }

  dynamic "subnet_mapping" {
    for_each = aws_subnet.firewall[*].id
    content {
      subnet_id = subnet_mapping.value
    }
  }

  tags = var.tags
}

#------------------------------------------------------------------------------
# Network Firewall Logging
#------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "firewall_alert" {
  count = var.enable_firewall_logs ? 1 : 0

  name              = "/aws/network-firewall/${var.name}/alert"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.log_kms_arn

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "firewall_flow" {
  count = var.enable_firewall_logs ? 1 : 0

  name              = "/aws/network-firewall/${var.name}/flow"
  retention_in_days = var.log_retention_days
  kms_key_id        = local.log_kms_arn

  tags = var.tags
}

resource "aws_networkfirewall_logging_configuration" "this" {
  count = var.enable_firewall_logs ? 1 : 0

  firewall_arn = aws_networkfirewall_firewall.this.arn

  logging_configuration {
    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.firewall_alert[0].name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "ALERT"
    }

    log_destination_config {
      log_destination = {
        logGroup = aws_cloudwatch_log_group.firewall_flow[0].name
      }
      log_destination_type = "CloudWatchLogs"
      log_type             = "FLOW"
    }
  }
}

#------------------------------------------------------------------------------
# Route Tables
#------------------------------------------------------------------------------

locals {
  firewall_endpoints = {
    for state in aws_networkfirewall_firewall.this.firewall_status[0].sync_states :
    state.availability_zone => state.attachment[0].endpoint_id
  }

  firewall_return_routes = var.transit_gateway_id != null ? {
    for pair in setproduct(range(local.az_count), var.private_return_cidrs) :
    "${local.azs[pair[0]]}-${replace(pair[1], "/", "-")}" => {
      idx  = pair[0]
      cidr = pair[1]
    }
  } : {}

  public_return_routes = var.enable_egress ? {
    for pair in setproduct(range(local.az_count), var.private_return_cidrs) :
    "${local.azs[pair[0]]}-${replace(pair[1], "/", "-")}" => {
      idx  = pair[0]
      az   = local.azs[pair[0]]
      cidr = pair[1]
    }
  } : {}
}

resource "aws_route_table" "firewall" {
  count = local.az_count

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-firewall-${local.azs[count.index]}"
  })
}

resource "aws_route" "firewall_to_nat" {
  count = var.enable_egress ? local.az_count : 0

  route_table_id         = aws_route_table.firewall[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.single_nat_gateway ? aws_nat_gateway.this[0].id : aws_nat_gateway.this[count.index].id
}

resource "aws_route" "firewall_to_tgw" {
  for_each = local.firewall_return_routes

  route_table_id         = aws_route_table.firewall[each.value.idx].id
  destination_cidr_block = each.value.cidr
  transit_gateway_id     = var.transit_gateway_id
}

resource "aws_route_table_association" "firewall" {
  count = local.az_count

  subnet_id      = aws_subnet.firewall[count.index].id
  route_table_id = aws_route_table.firewall[count.index].id
}

resource "aws_route_table" "tgw_attachment" {
  count = local.az_count

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-tgw-${local.azs[count.index]}"
  })
}

resource "aws_route" "tgw_to_firewall" {
  count = local.az_count

  route_table_id         = aws_route_table.tgw_attachment[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  vpc_endpoint_id        = local.firewall_endpoints[local.azs[count.index]]
}

resource "aws_route_table_association" "tgw_attachment" {
  count = local.az_count

  subnet_id      = aws_subnet.tgw_attachment[count.index].id
  route_table_id = aws_route_table.tgw_attachment[count.index].id
}

resource "aws_route_table" "public" {
  count = var.enable_egress ? local.az_count : 0

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-public-${local.azs[count.index]}"
  })
}

resource "aws_route" "public_to_igw" {
  count = var.enable_egress ? local.az_count : 0

  route_table_id         = aws_route_table.public[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

resource "aws_route" "public_to_firewall" {
  for_each = local.public_return_routes

  route_table_id         = aws_route_table.public[each.value.idx].id
  destination_cidr_block = each.value.cidr
  vpc_endpoint_id        = local.firewall_endpoints[each.value.az]
}

resource "aws_route_table_association" "public" {
  count = var.enable_egress ? local.az_count : 0

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[count.index].id
}

#------------------------------------------------------------------------------
# Transit Gateway Attachment - Appliance mode enabled
#------------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  count = var.transit_gateway_id != null ? 1 : 0

  transit_gateway_id = var.transit_gateway_id
  vpc_id             = aws_vpc.this.id
  subnet_ids         = aws_subnet.tgw_attachment[*].id

  appliance_mode_support                          = "enable"
  dns_support                                     = "enable"
  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = merge(var.tags, {
    Name    = "${var.name}-tgw-attachment"
    Purpose = "inspection"
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
# VPC Flow Logs
#------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/aws/vpc/${var.name}/flow-logs"
  retention_in_days = var.log_retention_days
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
