#------------------------------------------------------------------------------
# Simulated On-Premises Environment
#
# This module creates a VPC that simulates an on-premises data center,
# complete with an EC2 instance running strongSwan (IPsec) and FRR (BGP).
#
# IMPORTANT: This is a simulation for testing hybrid connectivity.
# In production, you would use:
# - AWS Direct Connect with a transit VIF to a DX Gateway associated with TGW
# - A physical or virtual customer gateway device at your data center
#
# The EC2 router:
# - Establishes dual IPsec tunnels to the AWS VPN endpoints
# - Runs BGP sessions over each tunnel to exchange routes
# - Advertises the on-premises CIDR (default: 10.200.0.0/16) to AWS
# - Receives routes from AWS for spoke VPCs and shared services
#------------------------------------------------------------------------------

data "aws_availability_zones" "available" {
  state = "available"
}

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
  az = var.availability_zone != null ? var.availability_zone : data.aws_availability_zones.available.names[0]
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

#------------------------------------------------------------------------------
# Subnets
#------------------------------------------------------------------------------

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 4, 0)
  availability_zone       = local.az
  map_public_ip_on_launch = true

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
  description = "Security group for VPN router"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "IKE"
    from_port   = 500
    to_port     = 500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "NAT-T"
    from_port   = 4500
    to_port     = 4500
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "ESP"
    from_port   = 0
    to_port     = 0
    protocol    = "50"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  ingress {
    description = "ICMP from VPC"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.vpc_cidr, "10.0.0.0/8"]
  }

  ingress {
    description = "All from private subnet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [cidrsubnet(var.vpc_cidr, 4, 1)]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
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

resource "aws_iam_instance_profile" "router" {
  name = "${var.name}-router-profile"
  role = aws_iam_role.router.name
}

#------------------------------------------------------------------------------
# EC2 Router Instance - strongSwan + FRR
#------------------------------------------------------------------------------

resource "aws_instance" "router" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  iam_instance_profile = aws_iam_instance_profile.router.name

  network_interface {
    network_interface_id = aws_network_interface.router_public.id
    device_index         = 0
  }

  network_interface {
    network_interface_id = aws_network_interface.router_private.id
    device_index         = 1
  }

  user_data = base64encode(templatefile("${path.module}/templates/router-userdata.sh.tpl", {
    onprem_cidr           = var.onprem_cidr_to_advertise
    customer_asn          = var.customer_bgp_asn
    aws_asn               = var.aws_bgp_asn
    tunnel1_aws_endpoint  = var.tunnel1_aws_endpoint
    tunnel1_psk           = var.tunnel1_psk
    tunnel1_cgw_inside_ip = var.tunnel1_cgw_inside_ip
    tunnel1_aws_inside_ip = var.tunnel1_aws_inside_ip
    tunnel2_aws_endpoint  = var.tunnel2_aws_endpoint
    tunnel2_psk           = var.tunnel2_psk
    tunnel2_cgw_inside_ip = var.tunnel2_cgw_inside_ip
    tunnel2_aws_inside_ip = var.tunnel2_aws_inside_ip
    private_interface_ip  = cidrhost(cidrsubnet(var.vpc_cidr, 4, 1), 10)
  }))

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
  description = "Security group for test instance"
  vpc_id      = aws_vpc.this.id

  ingress {
    description = "All from VPC and AWS"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr, "10.0.0.0/8"]
  }

  egress {
    description = "All outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
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

  tags = merge(var.tags, {
    Name = "${var.name}-test-instance"
  })
}
