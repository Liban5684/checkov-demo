# ── Networking ──────────────────────────────────────────────────────────────

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "checkov-demo-vpc" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = false

  tags = { Name = "checkov-demo-public-subnet" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "checkov-demo-igw" }
}

# ── S3 module ────────────────────────────────────────────────────────────────

module "s3" {
  source      = "./modules/s3"
  environment = var.environment
}

# ── EC2 module ───────────────────────────────────────────────────────────────

module "ec2" {
  source           = "./modules/ec2"
  environment      = var.environment
  subnet_id        = aws_subnet.public.id
  vpc_id           = aws_vpc.main.id
  instance_type    = var.app_instance_type
  allowed_ssh_cidr = var.allowed_ssh_cidr
}
