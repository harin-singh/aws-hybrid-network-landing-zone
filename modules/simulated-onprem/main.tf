#------------------------------------------------------------------------------
# Simulated On-Premises Environment
#
# EC2 router running strongSwan (IPsec) and FRR (BGP). This is a lab stand-in
# for a customer gateway; production hybrid connectivity is Site-to-Site VPN
# or Direct Connect to a physical/virtual CGW.
#
# Secrets: VPN PSKs are stored in SSM Parameter Store (SecureString) and
# fetched at boot via the instance role. They are not written to user_data.
#------------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

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

locals {
  az             = var.availability_zone != null ? var.availability_zone : data.aws_availability_zones.available.names[0]
  create_log_kms = var.enable_flow_logs && var.kms_key_id == null
  log_kms_arn    = var.kms_key_id != null ? var.kms_key_id : (local.create_log_kms ? aws_kms_key.logs[0].arn : null)
  store_psks     = var.tunnel1_psk != null || var.tunnel2_psk != null
}

#------------------------------------------------------------------------------
# VPC - Simulated Data Center
#------------------------------------------------------------------------------

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name    = var.name
    Purpose = "simulated-onprem"
  })
}

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-default-sg-locked"
  })
}

#------------------------------------------------------------------------------
# Subnets
#------------------------------------------------------------------------------

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, 0)
  availability_zone       = local.az
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.name}-public"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, 1)
  availability_zone = local.az

  tags = merge(var.tags, {
    Name = "${var.name}-private"
    Tier = "private"
  })
}

#------------------------------------------------------------------------------
# Internet Gateway - For VPN router public connectivity
#------------------------------------------------------------------------------

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-igw"
  })
}

#------------------------------------------------------------------------------
# Route Tables
#------------------------------------------------------------------------------

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, {
    Name = "${var.name}-public"
  })
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block           = "10.0.0.0/8"
    network_interface_id = aws_network_interface.router_private.id
  }

  tags = merge(var.tags, {
    Name = "${var.name}-private"
  })
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

#------------------------------------------------------------------------------
# Security Groups
#------------------------------------------------------------------------------

resource "aws_security_group" "router" {
  name        = "${var.name}-router"
  description = "VPN router: IPsec from AWS tunnel endpoints only"
  vpc_id      = aws_vpc.this.id

  dynamic "ingress" {
    for_each = length(var.ipsec_peer_cidrs) > 0 ? [1] : []
    content {
      description = "IKE from AWS VPN tunnel outside IPs"
      from_port   = 500
      to_port     = 500
      protocol    = "udp"
      cidr_blocks = var.ipsec_peer_cidrs
    }
  }

  dynamic "ingress" {
    for_each = length(var.ipsec_peer_cidrs) > 0 ? [1] : []
    content {
      description = "NAT-T from AWS VPN tunnel outside IPs"
      from_port   = 4500
      to_port     = 4500
      protocol    = "udp"
      cidr_blocks = var.ipsec_peer_cidrs
    }
  }

  dynamic "ingress" {
    for_each = length(var.ipsec_peer_cidrs) > 0 ? [1] : []
    content {
      description = "ESP from AWS VPN tunnel outside IPs"
      from_port   = 0
      to_port     = 0
      protocol    = "50"
      cidr_blocks = var.ipsec_peer_cidrs
    }
  }

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "ICMP from VPC and AWS RFC1918"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr, "10.0.0.0/8"]
  }

  ingress {
    description = "All from private subnet (on-prem LAN behind the router)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [cidrsubnet(var.vpc_cidr, 4, 1)]
  }

  egress {
    description = "IPsec IKE"
    from_port   = 500
    to_port     = 500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "IPsec NAT-T"
    from_port   = 4500
    to_port     = 4500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "ESP"
    from_port   = 0
    to_port     = 0
    protocol    = "50"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTPS for SSM, AWS APIs, and package repos"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "HTTP for package repos"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "DNS UDP"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "DNS TCP"
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "BGP over VTI (link-local 169.254.0.0/16 plus on-prem LAN)"
    from_port   = 179
    to_port     = 179
    protocol    = "tcp"
    cidr_blocks = ["169.254.0.0/16", var.vpc_cidr, "10.0.0.0/8"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-router"
  })
}

#------------------------------------------------------------------------------
# Network Interfaces
#------------------------------------------------------------------------------

resource "aws_network_interface" "router_public" {
  subnet_id         = aws_subnet.public.id
  security_groups   = [aws_security_group.router.id]
  source_dest_check = false

  tags = merge(var.tags, {
    Name = "${var.name}-router-public"
  })
}

resource "aws_network_interface" "router_private" {
  subnet_id         = aws_subnet.private.id
  security_groups   = [aws_security_group.router.id]
  source_dest_check = false
  private_ips       = [cidrhost(cidrsubnet(var.vpc_cidr, 4, 1), 10)]

  tags = merge(var.tags, {
    Name = "${var.name}-router-private"
  })
}

# checkov:skip=CKV2_AWS_19: EIP is associated to the dual-homed router ENI, not to instance_id
resource "aws_eip" "router" {
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name}-router"
  })
}

resource "aws_eip_association" "router" {
  allocation_id        = aws_eip.router.id
  network_interface_id = aws_network_interface.router_public.id
}

#------------------------------------------------------------------------------
# IAM Role for EC2 Instance
#------------------------------------------------------------------------------

resource "aws_iam_role" "router" {
  name = "${var.name}-router-role"

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

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.router.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "router_ssm_psk" {
  count = local.store_psks ? 1 : 0

  statement {
    sid     = "ReadVpnPsks"
    effect  = "Allow"
    actions = ["ssm:GetParameter", "ssm:GetParameters"]
    resources = compact([
      var.tunnel1_psk != null ? aws_ssm_parameter.tunnel1_psk[0].arn : null,
      var.tunnel2_psk != null ? aws_ssm_parameter.tunnel2_psk[0].arn : null,
    ])
  }

  statement {
    sid       = "DecryptSecureString"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = [local.store_psks ? aws_kms_key.psk[0].arn : "*"]
  }
}

resource "aws_iam_role_policy" "router_ssm_psk" {
  count = local.store_psks ? 1 : 0

  name   = "${var.name}-router-ssm-psk"
  role   = aws_iam_role.router.id
  policy = data.aws_iam_policy_document.router_ssm_psk[0].json
}

resource "aws_iam_instance_profile" "router" {
  name = "${var.name}-router-profile"
  role = aws_iam_role.router.name
}

#------------------------------------------------------------------------------
# VPN PSKs in SSM (never written to user_data)
#------------------------------------------------------------------------------

resource "aws_kms_key" "psk" {
  count = local.store_psks ? 1 : 0

  description             = "${var.name} VPN pre-shared key encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.psk_kms[0].json

  tags = var.tags
}

data "aws_iam_policy_document" "psk_kms" {
  count = local.store_psks ? 1 : 0

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
    sid    = "AllowRouterDecrypt"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.router.arn]
    }
    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = ["*"]
  }
}

resource "aws_ssm_parameter" "tunnel1_psk" {
  count = var.tunnel1_psk != null ? 1 : 0

  name   = "/${var.name}/vpn/tunnel1-psk"
  type   = "SecureString"
  key_id = aws_kms_key.psk[0].id
  value  = var.tunnel1_psk

  tags = var.tags
}

resource "aws_ssm_parameter" "tunnel2_psk" {
  count = var.tunnel2_psk != null ? 1 : 0

  name   = "/${var.name}/vpn/tunnel2-psk"
  type   = "SecureString"
  key_id = aws_kms_key.psk[0].id
  value  = var.tunnel2_psk

  tags = var.tags
}

#------------------------------------------------------------------------------
# EC2 Router Instance - strongSwan + FRR
#------------------------------------------------------------------------------

resource "aws_instance" "router" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type
  ebs_optimized = true

  iam_instance_profile = aws_iam_instance_profile.router.name

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  network_interface {
    network_interface_id = aws_network_interface.router_public.id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.router_private.id
    device_index         = 1
  }

  user_data = templatefile("${path.module}/templates/router-userdata.sh.tpl", {
    onprem_cidr           = var.onprem_cidr_to_advertise
    vpc_cidr              = var.vpc_cidr
    customer_asn          = var.customer_bgp_asn
    aws_asn               = var.aws_bgp_asn
    tunnel1_aws_endpoint  = var.tunnel1_aws_endpoint
    tunnel1_psk_parameter = var.tunnel1_psk != null ? aws_ssm_parameter.tunnel1_psk[0].name : ""
    tunnel1_cgw_inside_ip = var.tunnel1_cgw_inside_ip
    tunnel1_aws_inside_ip = var.tunnel1_aws_inside_ip
    tunnel2_aws_endpoint  = var.tunnel2_aws_endpoint
    tunnel2_psk_parameter = var.tunnel2_psk != null ? aws_ssm_parameter.tunnel2_psk[0].name : ""
    tunnel2_cgw_inside_ip = var.tunnel2_cgw_inside_ip
    tunnel2_aws_inside_ip = var.tunnel2_aws_inside_ip
    private_interface_ip  = cidrhost(cidrsubnet(var.vpc_cidr, 4, 1), 10)
  })

  tags = merge(var.tags, {
    Name = "${var.name}-router"
  })

  lifecycle {
    ignore_changes = [ami]
  }
}

#------------------------------------------------------------------------------
# Test Instance in Private Subnet
#------------------------------------------------------------------------------

resource "aws_security_group" "test_instance" {
  count = var.create_test_instance ? 1 : 0

  name        = "${var.name}-test-instance"
  description = "Security group for on-prem test instance"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "ICMP from on-prem VPC and AWS RFC1918"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr, "10.0.0.0/8"]
  }

  egress {
    description = "ICMP for connectivity tests"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr, "10.0.0.0/8"]
  }

  egress {
    description = "HTTPS for SSM"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name}-test-instance"
  })
}

resource "aws_instance" "test" {
  count = var.create_test_instance ? 1 : 0

  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.test_instance[0].id]
  iam_instance_profile   = aws_iam_instance_profile.router.name
  ebs_optimized          = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "disabled"
  }

  root_block_device {
    encrypted   = true
    volume_type = "gp3"
  }

  tags = merge(var.tags, {
    Name = "${var.name}-test-instance"
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
