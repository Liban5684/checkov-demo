# ── Variables ────────────────────────────────────────────────────────────────

variable "environment"      { type = string }
variable "subnet_id"        { type = string }
variable "vpc_id"           { type = string }
variable "instance_type"    { type = string }
variable "allowed_ssh_cidr" { type = string }

# ── Latest Amazon Linux 2023 AMI ─────────────────────────────────────────────

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# ── Security group (INTENTIONALLY misconfigured) ──────────────────────────────
# ⚠️  CKV_AWS_25 – SSH open to the world (0.0.0.0/0)

resource "aws_security_group" "app" {
  name        = "checkov-demo-app-sg-${var.environment}"
  description = "Security group for the application server"
  vpc_id      = var.vpc_id

  # ⚠️  CKV_AWS_25 – wide-open SSH; restrict to a bastion or VPN CIDR in prod
  ingress {
    description = "SSH from anywhere – DEMO ONLY"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ── IAM role for the EC2 instance ────────────────────────────────────────────

resource "aws_iam_role" "app" {
  name = "checkov-demo-app-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_instance_profile" "app" {
  name = "checkov-demo-app-profile-${var.environment}"
  role = aws_iam_role.app.name
}

# ── EBS encryption key ────────────────────────────────────────────────────────

resource "aws_kms_key" "ebs" {
  description             = "KMS key for EBS volume encryption"
  deletion_window_in_days = 14
  enable_key_rotation     = true
}

# ── EC2 Instance (INTENTIONALLY misconfigured) ────────────────────────────────
# ⚠️  CKV_AWS_8  – IMDSv2 not enforced (http_tokens should be "required")
# ⚠️  CKV_AWS_135 – EBS volume not optimised

resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  iam_instance_profile   = aws_iam_instance_profile.app.name
  vpc_security_group_ids = [aws_security_group.app.id]

  # ⚠️  CKV_AWS_8 – omitting http_tokens = "required" leaves IMDSv1 open
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional"   # should be "required" to enforce IMDSv2
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    encrypted             = true          # ✅  CKV_AWS_8 (root vol)
    kms_key_id            = aws_kms_key.ebs.arn
    delete_on_termination = true
  }

  monitoring = true   # ✅  CKV_AWS_126 – detailed monitoring on

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y amazon-cloudwatch-agent
  EOF

  tags = { Name = "checkov-demo-app-${var.environment}" }
}

# ── Outputs ───────────────────────────────────────────────────────────────────

output "instance_id" {
  value = aws_instance.app.id
}
