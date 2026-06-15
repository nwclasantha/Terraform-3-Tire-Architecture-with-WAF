data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ========================================================================
# Path 1: VPC Flow Logs -> CloudWatch Logs (operational / near-real-time)
# ========================================================================
resource "aws_cloudwatch_log_group" "flow" {
  name              = "/vpc/${var.name}/flow-logs"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = merge(var.tags, { Name = "${var.name}-flow-logs" })
}

data "aws_iam_policy_document" "flow_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "flow" {
  name               = "${var.name}-flow-logs-role"
  assume_role_policy = data.aws_iam_policy_document.flow_assume.json
  tags               = var.tags
}

# Stream-level log actions require a ":*" stream wildcard within THIS specific log group
# (AWS-required pattern for VPC flow-log delivery); not an account-wide wildcard.
#tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "flow_publish" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = ["${aws_cloudwatch_log_group.flow.arn}:*"]
  }

  # DescribeLogGroups acts at the group level, not the stream level.
  statement {
    effect    = "Allow"
    actions   = ["logs:DescribeLogGroups"]
    resources = [aws_cloudwatch_log_group.flow.arn]
  }
}

resource "aws_iam_role_policy" "flow" {
  name   = "${var.name}-flow-logs-policy"
  role   = aws_iam_role.flow.id
  policy = data.aws_iam_policy_document.flow_publish.json
}

resource "aws_flow_log" "cloudwatch" {
  vpc_id                   = var.vpc_id
  traffic_type             = "ALL"
  log_destination_type     = "cloud-watch-logs"
  log_destination          = aws_cloudwatch_log_group.flow.arn
  iam_role_arn             = aws_iam_role.flow.arn
  max_aggregation_interval = 60
  tags                     = merge(var.tags, { Name = "${var.name}-flow-cw" })
}

# ========================================================================
# Path 2: VPC Flow Logs -> private S3 bucket (long-term / SOC forwarding)
# ========================================================================
# This IS the SOC log sink; object access is audited via CloudTrail S3 data events.
#tfsec:ignore:aws-s3-enable-bucket-logging
resource "aws_s3_bucket" "flow" {
  bucket        = "${var.name}-vpc-flow-logs-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  tags          = merge(var.tags, { Name = "${var.name}-flow-logs-bucket", Purpose = "SOC-flow-logs" })
}

resource "aws_s3_bucket_public_access_block" "flow" {
  bucket                  = aws_s3_bucket.flow.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "flow" {
  bucket = aws_s3_bucket.flow.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "flow" {
  bucket = aws_s3_bucket.flow.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "flow" {
  bucket = aws_s3_bucket.flow.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "flow" {
  bucket = aws_s3_bucket.flow.id
  rule {
    id     = "expire-flow-logs"
    status = "Enabled"
    filter {}
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    expiration {
      days = var.s3_retention_days
    }
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# Bucket policy allowing the AWS log-delivery service to write flow logs, TLS-only.
data "aws_iam_policy_document" "flow_bucket" {
  statement {
    sid    = "AWSLogDeliveryWrite"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.flow.arn}/AWSLogs/${data.aws_caller_identity.current.account_id}/*"]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid    = "AWSLogDeliveryAclCheck"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    actions   = ["s3:GetBucketAcl", "s3:ListBucket"]
    resources = [aws_s3_bucket.flow.arn]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.flow.arn, "${aws_s3_bucket.flow.arn}/*"]
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "flow" {
  bucket = aws_s3_bucket.flow.id
  policy = data.aws_iam_policy_document.flow_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.flow]
}

resource "aws_flow_log" "s3" {
  vpc_id                   = var.vpc_id
  traffic_type             = "ALL"
  log_destination_type     = "s3"
  log_destination          = aws_s3_bucket.flow.arn
  max_aggregation_interval = 60

  destination_options {
    file_format                = "parquet"
    per_hour_partition         = true
    hive_compatible_partitions = true
  }

  tags = merge(var.tags, { Name = "${var.name}-flow-s3" })

  depends_on = [aws_s3_bucket_policy.flow]
}
