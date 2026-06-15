data "aws_caller_identity" "current" {}

# Private S3 bucket for generated .ovpn client profiles. Access audited via CloudTrail data events.
#tfsec:ignore:aws-s3-enable-bucket-logging
resource "aws_s3_bucket" "profiles" {
  bucket        = "${var.name}-vpn-profiles-${data.aws_caller_identity.current.account_id}"
  force_destroy = true
  tags          = merge(var.tags, { Name = "${var.name}-vpn-profiles" })
}

resource "aws_s3_bucket_public_access_block" "profiles" {
  bucket                  = aws_s3_bucket.profiles.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "profiles" {
  bucket = aws_s3_bucket.profiles.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_versioning" "profiles" {
  bucket = aws_s3_bucket.profiles.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ----- IAM role for the OpenVPN instance: SSM + write profiles + validate Cognito -----
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "bastion" {
  name               = "${var.name}-bastion-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# s3:PutObject needs an object-key wildcard to write per-user profiles; scoped to one
# bucket + the "profiles/" prefix only.
#tfsec:ignore:aws-iam-no-policy-wildcards
data "aws_iam_policy_document" "bastion" {
  statement {
    sid       = "WriteProfiles"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.profiles.arn}/profiles/*"]
  }
  # Scoped to THIS user pool ARN (no wildcard).
  statement {
    sid       = "ValidateCognito"
    effect    = "Allow"
    actions   = ["cognito-idp:AdminInitiateAuth", "cognito-idp:AdminRespondToAuthChallenge"]
    resources = [var.cognito_user_pool_arn]
  }
  # Encrypt profile objects with the data CMK.
  statement {
    sid       = "UseDataKey"
    effect    = "Allow"
    actions   = ["kms:GenerateDataKey", "kms:Encrypt", "kms:Decrypt", "kms:DescribeKey"]
    resources = [var.kms_key_arn]
  }
}

resource "aws_iam_role_policy" "bastion" {
  name   = "${var.name}-bastion-policy"
  role   = aws_iam_role.bastion.id
  policy = data.aws_iam_policy_document.bastion.json
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.name}-bastion-profile"
  role = aws_iam_role.bastion.name
}

# ----- OpenVPN server -----
resource "aws_instance" "openvpn" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [var.bastion_sg_id]
  iam_instance_profile        = aws_iam_instance_profile.bastion.name
  key_name                    = var.key_name != "" ? var.key_name : null
  associate_public_ip_address = true
  source_dest_check           = false # required for VPN routing/NAT

  user_data = templatefile("${path.module}/../../scripts/install_openvpn.sh", {
    vpc_cidr           = var.vpc_cidr
    aws_region         = var.aws_region
    oidc_issuer        = var.oidc_issuer
    oidc_client_id     = var.oidc_client_id
    oidc_client_secret = var.oidc_client_secret
    profiles_bucket    = aws_s3_bucket.profiles.id
  })

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  root_block_device {
    encrypted   = true
    volume_size = 10
    volume_type = "gp3"
  }

  tags = merge(var.tags, { Name = "${var.name}-openvpn", Tier = "bastion" })
}

resource "aws_eip" "openvpn" {
  instance = aws_instance.openvpn.id
  domain   = "vpc"
  tags     = merge(var.tags, { Name = "${var.name}-openvpn-eip" })
}
