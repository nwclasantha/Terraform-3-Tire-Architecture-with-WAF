output "logs_key_arn" {
  description = "CMK ARN for CloudWatch logs and flow-log S3 bucket."
  value       = aws_kms_key.logs.arn
}

output "data_key_arn" {
  description = "CMK ARN for Secrets Manager and VPN profiles S3 bucket."
  value       = aws_kms_key.data.arn
}
