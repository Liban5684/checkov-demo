# ── Variables ────────────────────────────────────────────────────────────────

variable "environment" {
  type = string
}

# ── KMS key for encryption ───────────────────────────────────────────────────

resource "aws_kms_key" "s3" {
  description             = "KMS key for S3 bucket encryption"
  deletion_window_in_days = 14
  enable_key_rotation     = true   # ✅  CKV_AWS_7 – key rotation enabled
}

# ── Application bucket (CORRECTLY configured) ────────────────────────────────

resource "aws_s3_bucket" "app" {
  bucket = "checkov-demo-app-${var.environment}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_versioning" "app" {
  bucket = aws_s3_bucket.app.id
  versioning_configuration {
    status     = "Enabled"   # ✅  CKV_AWS_52
    mfa_delete = "Disabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app" {
  bucket = aws_s3_bucket.app.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"          # ✅  CKV_AWS_19
      kms_master_key_id = aws_kms_key.s3.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "app" {
  bucket                  = aws_s3_bucket.app.id
  block_public_acls       = true    # ✅  CKV_AWS_53
  block_public_policy     = true    # ✅  CKV_AWS_54
  ignore_public_acls      = true    # ✅  CKV_AWS_55
  restrict_public_buckets = true    # ✅  CKV_AWS_56
}

resource "aws_s3_bucket_logging" "app" {
  bucket        = aws_s3_bucket.app.id
  target_bucket = aws_s3_bucket.logs.id   # ✅  CKV_AWS_18
  target_prefix = "app-access-logs/"
}

# ── Log bucket (INTENTIONALLY misconfigured for demo) ────────────────────────
# Checkov will flag:
#   CKV_AWS_20  – bucket ACL allows public read
#   CKV_AWS_52  – MFA delete not enabled on versioning
#   CKV_AWS_18  – no access logging on the log bucket itself

resource "aws_s3_bucket" "logs" {
  bucket = "checkov-demo-logs-${var.environment}-${data.aws_caller_identity.current.account_id}"
}

# ⚠️  CKV_AWS_20 – public-read ACL exposes objects to the internet
resource "aws_s3_bucket_acl" "logs" {
  bucket = aws_s3_bucket.logs.id
  acl    = "public-read"
}

# ⚠️  CKV_AWS_52 – versioning enabled but MFA delete is off
resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status     = "Enabled"
    mfa_delete = "Disabled"
  }
}

# Missing: aws_s3_bucket_server_side_encryption_configuration  ⚠️  CKV_AWS_19
# Missing: aws_s3_bucket_public_access_block                   ⚠️  CKV_AWS_53-56
# Missing: aws_s3_bucket_logging                               ⚠️  CKV_AWS_18

# ── Data sources ─────────────────────────────────────────────────────────────

data "aws_caller_identity" "current" {}

# ── Outputs ──────────────────────────────────────────────────────────────────

output "app_bucket_name" {
  value = aws_s3_bucket.app.bucket
}

output "log_bucket_name" {
  value = aws_s3_bucket.logs.bucket
}
