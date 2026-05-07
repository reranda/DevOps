resource "aws_s3_bucket" "demo_bucket" {
  #checkov:skip=CKV_AWS_18:Access logging will be added later with a dedicated logging bucket
  #checkov:skip=CKV2_AWS_62:Event notifications are not required for this demo bucket
  #checkov:skip=CKV_AWS_144:Cross-region replication is not required for this lab environment

  bucket = var.bucket_name

  tags = {
    Name        = "${var.project_name}-${var.bucket_name}"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "demo_bucket" {
  bucket = aws_s3_bucket.demo_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "demo_bucket" {
  bucket = aws_s3_bucket.demo_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "demo_bucket" {
  bucket = aws_s3_bucket.demo_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }

    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "demo_bucket" {
  bucket = aws_s3_bucket.demo_bucket.id

  rule {
    id     = "delete-old-noncurrent-versions-and-abort-incomplete-uploads"
    status = "Enabled"

    filter {
      prefix = ""
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

resource "aws_vpc" "main" {
  #checkov:skip=CKV2_AWS_11:VPC flow logs will be added later with CloudWatch log group and IAM role

  cidr_block = "10.0.0.0/16"

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  ingress = []
  egress  = []

  tags = {
    Name        = "${var.project_name}-default-sg-restricted"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}