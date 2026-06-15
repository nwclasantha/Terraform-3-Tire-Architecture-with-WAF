# Shared EC2 instance profile granting SSM Session Manager access (no SSH keys needed).
# Used by the web tier, MySQL server, and Jenkins master/slaves.
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ssm" {
  name               = "${var.project}-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "${var.project}-ssm-profile"
  role = aws_iam_role.ssm.name
}

# ---------------------------------------------------------------------------
# Dedicated web-tier role: SSM + read ONLY the DB connection secret.
# Mapped to the web EC2 instances so they retrieve the password securely at
# runtime from Secrets Manager (least privilege; no creds in user-data).
# ---------------------------------------------------------------------------
resource "aws_iam_role" "web" {
  name               = "${var.project}-web-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
}

resource "aws_iam_role_policy_attachment" "web_ssm_core" {
  role       = aws_iam_role.web.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

data "aws_iam_policy_document" "web_secret_read" {
  statement {
    sid       = "ReadDbConnectionSecret"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [module.secrets.secret_arn]
  }
  # Decrypt the CMK-encrypted secret value.
  statement {
    sid       = "DecryptSecretWithCmk"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:DescribeKey"]
    resources = [module.kms.data_key_arn]
  }
}

resource "aws_iam_role_policy" "web_secret_read" {
  name   = "${var.project}-web-secret-read"
  role   = aws_iam_role.web.id
  policy = data.aws_iam_policy_document.web_secret_read.json
}

resource "aws_iam_instance_profile" "web" {
  name = "${var.project}-web-profile"
  role = aws_iam_role.web.name
}
