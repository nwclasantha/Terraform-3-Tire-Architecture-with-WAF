data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
}

# ============================================================================
# Logs CMK — encrypts the CloudWatch flow-log group AND the flow-logs S3 bucket.
# Key policy must allow the CloudWatch Logs service and the VPC flow-log delivery
# service to use the key, in addition to full control by the account root.
# ============================================================================
data "aws_iam_policy_document" "logs" {
  statement {
    sid       = "EnableRoot"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
  }

  statement {
    sid    = "AllowCloudWatchLogs"
    effect = "Allow"
    actions = [
      "kms:Encrypt*",
      "kms:Decrypt*",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
    ]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["logs.${local.region}.amazonaws.com"]
    }
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${local.region}:${local.account_id}:log-group:*"]
    }
  }

  statement {
    sid    = "AllowFlowLogDelivery"
    effect = "Allow"
    actions = [
      "kms:GenerateDataKey*",
      "kms:Decrypt",
      "kms:Encrypt",
      "kms:ReEncrypt*",
      "kms:DescribeKey",
    ]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["delivery.logs.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_kms_key" "logs" {
  description             = "${var.name} logs CMK (CloudWatch + flow-log S3)"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.logs.json
  tags                    = var.tags
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${var.name}-logs"
  target_key_id = aws_kms_key.logs.key_id
}

# ============================================================================
# Data CMK — encrypts the DB connection secret and the VPN profiles S3 bucket.
# Account root retains full control; consuming roles are granted kms:Decrypt /
# kms:GenerateDataKey via their own IAM policies (scoped to this key ARN).
# ============================================================================
data "aws_iam_policy_document" "data" {
  statement {
    sid       = "EnableRoot"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${local.account_id}:root"]
    }
  }

  statement {
    sid    = "AllowSecretsManager"
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["secretsmanager.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "kms:CallerAccount"
      values   = [local.account_id]
    }
  }
}

resource "aws_kms_key" "data" {
  description             = "${var.name} data CMK (Secrets Manager + VPN profiles S3)"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  policy                  = data.aws_iam_policy_document.data.json
  tags                    = var.tags
}

resource "aws_kms_alias" "data" {
  name          = "alias/${var.name}-data"
  target_key_id = aws_kms_key.data.key_id
}
