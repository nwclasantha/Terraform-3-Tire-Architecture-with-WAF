output "secret_arn" {
  description = "ARN of the DB connection secret."
  value       = aws_secretsmanager_secret.db.arn
}

output "secret_name" {
  description = "Name/ID of the DB connection secret."
  value       = aws_secretsmanager_secret.db.name
}
