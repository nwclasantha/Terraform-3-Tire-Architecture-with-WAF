output "log_group_name" {
  description = "CloudWatch Logs group receiving VPC flow logs."
  value       = aws_cloudwatch_log_group.flow.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch Logs group."
  value       = aws_cloudwatch_log_group.flow.arn
}

output "flow_logs_bucket_name" {
  description = "Private S3 bucket holding VPC flow logs for SOC forwarding."
  value       = aws_s3_bucket.flow.id
}

output "flow_logs_bucket_arn" {
  description = "ARN of the private flow-logs S3 bucket."
  value       = aws_s3_bucket.flow.arn
}
