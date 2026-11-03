#------------------------------------------------------------------------------
# Shared Services VPC - Central DNS and shared infrastructure
#
# Design decisions:
# - Route 53 Resolver endpoints: Inbound (on-prem → AWS) and outbound (AWS → on-prem)
# - Private hosted zones: Associated with all spoke VPCs via RAM
# - Forwarding rules: Shared via RAM for corp.example.internal → on-prem DNS
# - TGW attachment: Propagates to all route tables for reachability
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
    Purpose = "shared-services"
  })
}

#------------------------------------------------------------------------------
# Subnets
#------------------------------------------------------------------------------

resource "aws_subnet" "private" {
  count = local.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.cidr_block, 4, count.index)
  availability_zone = local.azs[count.index]

  tags = merge(var.tags, {
    Name = "${var.name}-private-${local.azs[count.index]}"
    Tier = "private"
  })
}

resource "aws_subnet" "resolver" {
  count = local.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.cidr_block, 4, count.index + 4)
  availability_zone = local.azs[count.index]

  tags = merge(var.tags, {
    Name = "${var.name}-resolver-${local.azs[count.index]}"
    Tier = "resolver"
  })
}

resource "aws_subnet" "tgw_attachment" {
  count = local.az_count

  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.cidr_block, 8, count.index + 200)
  availability_zone = local.azs[count.index]

  tags = merge(var.tags, {
    Name = "${var.name}-tgw-${local.azs[count.index]}"
    Tier = "tgw-attachment"
  })
}

#------------------------------------------------------------------------------
# Route Tables
#------------------------------------------------------------------------------

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-private"
  })
}

resource "aws_route_table_association" "private" {
  count = local.az_count

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "resolver" {
  count = local.az_count

  subnet_id      = aws_subnet.resolver[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table" "tgw_attachment" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-tgw-attachment"
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
    Name    = "${var.name}-tgw-attachment"
    Purpose = "shared-services"
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
# Route 53 Resolver - Security Group
#------------------------------------------------------------------------------

resource "aws_security_group" "resolver" {
  count = var.enable_resolver_endpoints ? 1 : 0

  name        = "${var.name}-resolver"
  description = "Security group for Route 53 Resolver endpoints"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "DNS from VPC and spoke networks"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = concat([aws_vpc.this.cidr_block], var.resolver_allowed_cidrs)
  }

  ingress {
    description = "DNS from VPC and spoke networks"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = concat([aws_vpc.this.cidr_block], var.resolver_allowed_cidrs)
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-resolver"
  })
}

#------------------------------------------------------------------------------
# Route 53 Resolver - Inbound Endpoint (On-prem → AWS)
#------------------------------------------------------------------------------

resource "aws_route53_resolver_endpoint" "inbound" {
  count = var.enable_resolver_endpoints ? 1 : 0

  name      = "${var.name}-inbound"
  direction = "INBOUND"

  security_group_ids = [aws_security_group.resolver[0].id]

  dynamic "ip_address" {
    for_each = aws_subnet.resolver[*].id
    content {
      subnet_id = ip_address.value
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name}-inbound"
  })
}

#------------------------------------------------------------------------------
# Route 53 Resolver - Outbound Endpoint (AWS → On-prem)
#------------------------------------------------------------------------------

resource "aws_route53_resolver_endpoint" "outbound" {
  count = var.enable_resolver_endpoints ? 1 : 0

  name      = "${var.name}-outbound"
  direction = "OUTBOUND"

  security_group_ids = [aws_security_group.resolver[0].id]

  dynamic "ip_address" {
    for_each = aws_subnet.resolver[*].id
    content {
      subnet_id = ip_address.value
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name}-outbound"
  })
}

#------------------------------------------------------------------------------
# Resolver Forwarding Rules - On-prem DNS resolution
#------------------------------------------------------------------------------

resource "aws_route53_resolver_rule" "forward" {
  for_each = var.enable_resolver_endpoints && var.enable_forwarding_rules ? toset(var.onprem_domains) : toset([])

  domain_name          = each.value
  name                 = replace("${var.name}-${each.value}", ".", "-")
  rule_type            = "FORWARD"
  resolver_endpoint_id = aws_route53_resolver_endpoint.outbound[0].id

  dynamic "target_ip" {
    for_each = var.onprem_dns_servers
    content {
      ip   = target_ip.value
      port = 53
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name}-${each.value}"
  })
}

#------------------------------------------------------------------------------
# RAM Share - Share forwarding rules with spoke accounts
#------------------------------------------------------------------------------

resource "aws_ram_resource_share" "resolver_rules" {
  count = var.enable_resolver_endpoints && var.enable_forwarding_rules && var.share_resolver_rules && length(var.ram_principals) > 0 ? 1 : 0

  name                      = "${var.name}-resolver-rules"
  allow_external_principals = var.ram_allow_external_principals

  tags = merge(var.tags, {
    Name = "${var.name}-resolver-rules"
  })
}

resource "aws_ram_resource_association" "resolver_rules" {
  for_each = var.enable_resolver_endpoints && var.enable_forwarding_rules && var.share_resolver_rules && length(var.ram_principals) > 0 ? toset(var.onprem_domains) : toset([])

  resource_arn       = aws_route53_resolver_rule.forward[each.value].arn
  resource_share_arn = aws_ram_resource_share.resolver_rules[0].arn
}

resource "aws_ram_principal_association" "resolver_rules" {
  for_each = var.enable_resolver_endpoints && var.enable_forwarding_rules && var.share_resolver_rules ? toset(var.ram_principals) : toset([])

  principal          = each.value
  resource_share_arn = aws_ram_resource_share.resolver_rules[0].arn
}

#------------------------------------------------------------------------------
# Route 53 Private Hosted Zones
#------------------------------------------------------------------------------

resource "aws_route53_zone" "private" {
  for_each = var.enable_private_zones ? toset(var.private_zone_names) : toset([])

  name = each.value

  vpc {
    vpc_id = aws_vpc.this.id
  }

  lifecycle {
    ignore_changes = [vpc]
  }

  tags = merge(var.tags, {
    Name = each.value
  })
}

#------------------------------------------------------------------------------
# VPC Flow Logs
#------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "flow_logs" {
  count = var.enable_flow_logs ? 1 : 0

  name              = "/aws/vpc/${var.name}/flow-logs"
  retention_in_days = var.flow_logs_retention_days
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
