provider "aws" {
  region = var.aws_region

  dynamic "assume_role" {
    for_each = var.network_assume_role_arn != null ? [var.network_assume_role_arn] : []
    content {
      role_arn = assume_role.value
    }
  }
}

provider "aws" {
  alias  = "management"
  region = var.aws_region

  dynamic "assume_role" {
    for_each = var.management_assume_role_arn != null ? [var.management_assume_role_arn] : []
    content {
      role_arn = assume_role.value
    }
  }

  default_tags {
    tags = {
      Project   = "aws-hybrid-network-landing-zone"
      Example   = "multi-account"
      ManagedBy = "terraform"
    }
  }
}

provider "aws" {
  alias  = "network"
  region = var.aws_region

  dynamic "assume_role" {
    for_each = var.network_assume_role_arn != null ? [var.network_assume_role_arn] : []
    content {
      role_arn = assume_role.value
    }
  }

  default_tags {
    tags = {
      Project   = "aws-hybrid-network-landing-zone"
      Example   = "multi-account"
      Account   = "network"
      ManagedBy = "terraform"
    }
  }
}

provider "aws" {
  alias  = "workload"
  region = var.aws_region

  dynamic "assume_role" {
    for_each = var.workload_assume_role_arn != null ? [var.workload_assume_role_arn] : []
    content {
      role_arn = assume_role.value
    }
  }

  default_tags {
    tags = {
      Project   = "aws-hybrid-network-landing-zone"
      Example   = "multi-account"
      Account   = "workload"
      ManagedBy = "terraform"
    }
  }
}
