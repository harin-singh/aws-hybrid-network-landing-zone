#------------------------------------------------------------------------------
# Inspection VPC - Centralized AWS Network Firewall
#
# Design decisions:
# - Appliance mode enabled: Ensures symmetric routing through firewall
# - Separate firewall subnets: Network Firewall endpoints in dedicated subnets
# - Stateful inspection: East-west and egress traffic inspection
# - Return routing: Traffic returns through same firewall endpoint
#
# Traffic flow:
# 1. Spoke VPC → TGW → Inspection VPC firewall subnet
# 2. Network Firewall inspects → forward/drop
# 3. If egress: → NAT Gateway → IGW → Internet
# 4. Return traffic: IGW → NAT → Firewall → TGW → Spoke
#------------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs      = var.availability_zones != null ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, var.az_count)
  az_count = length(local.azs)
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
# AWS Network Firewall
#------------------------------------------------------------------------------

resource "aws_networkfirewall_firewall_policy" "this" {
  name = "${var.name}-policy"

  firewall_policy {
    stateless_default_actions          = ["aws:forward_to_sfe"]
    stateless_fragment_default_actions = ["aws:forward_to_sfe"]

    stateful_engine_options {
      rule_order = "STRICT_ORDER"
    }

    stateful_rule_group_reference {
      priority     = 100
      resource_arn = aws_networkfirewall_rule_group.domain_filter.arn
    }

    stateful_rule_group_reference {
      priority     = 200
      resource_arn = aws_networkfirewall_rule_group.threat_signatures.arn
    }
  }

  tags = var.tags
}

resource "aws_networkfirewall_rule_group" "domain_filter" {
  capacity = 100
  name     = "${var.name}-domain-filter"
  type     = "STATEFUL"

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

resource "aws_networkfirewall_rule_group" "threat_signatures" {
  capacity = 1000
  name     = "${var.name}-threat-signatures"
  type     = "STATEFUL"

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
      rules_string = <<-EOT
        # Drop known malicious patterns
        drop tcp $HOME_NET any -> any any (msg:"Block outbound to suspicious ports"; flow:to_server,established; content:"malware"; sid:1000001; rev:1;)
        # Alert on potential data exfiltration
        alert tcp $HOME_NET any -> any 443 (msg:"HTTPS traffic - monitoring"; flow:to_server,established; sid:1000002; rev:1;)
        # Pass other traffic
        pass tcp $HOME_NET any -> any any (msg:"Allow other TCP"; flow:to_server,established; sid:1000003; rev:1;)
        pass udp $HOME_NET any -> any any (msg:"Allow UDP"; sid:1000004; rev:1;)
        pass icmp any any -> any any (msg:"Allow ICMP"; sid:1000005; rev:1;)
      EOT
    }

    stateful_rule_options {
      rule_order = "STRICT_ORDER"
    }
  }

  tags = var.tags
}

resource "aws_networkfirewall_firewall" "this" {
  name                = var.name
  firewall_policy_arn = aws_networkfirewall_firewall_policy.this.arn
  vpc_id              = aws_vpc.this.id

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
  kms_key_id        = var.kms_key_id

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "firewall_flow" {
  count = var.enable_firewall_logs ? 1 : 0

  name              = "/aws/network-firewall/${var.name}/flow"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_id

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
  count = var.transit_gateway_id != null ? local.az_count : 0

  route_table_id         = aws_route_table.firewall[count.index].id
  destination_cidr_block = var.spoke_cidrs_aggregate
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
  count = var.enable_egress ? 1 : 0

  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-public"
  })
}

resource "aws_route" "public_to_igw" {
  count = var.enable_egress ? 1 : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id
}

resource "aws_route" "public_to_firewall" {
  count = var.enable_egress ? local.az_count : 0

  route_table_id         = aws_route_table.public[0].id
  destination_cidr_block = var.spoke_cidrs_aggregate
  vpc_endpoint_id        = local.firewall_endpoints[local.azs[count.index]]
}

resource "aws_route_table_association" "public" {
  count = var.enable_egress ? local.az_count : 0

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public[0].id
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
  kms_key_id        = var.kms_key_id

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
