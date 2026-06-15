# Database connection secret. The web tier reads this at runtime via its instance role,
# so no DB password is ever baked into user-data or AMIs. Encrypted with the AWS-managed
# key for Secrets Manager by default.
resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.name}/db/connection"
  description             = "DB connection string + credentials for the web tier"
  recovery_window_in_days = var.recovery_window_days
  kms_key_id              = var.kms_key_arn
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    host     = var.db_host
    port     = var.db_port
    dbname   = var.db_name
    username = var.db_username
    password = var.db_password
    # Ready-to-use connection string (consumers may use this directly).
    uri = "mysql://${var.db_username}:${var.db_password}@${var.db_host}:${var.db_port}/${var.db_name}"
  })
}
