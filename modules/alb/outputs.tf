output "alb_arn" {
  description = "ARN of the ALB (used for the WAF association)."
  value       = aws_lb.this.arn
}

output "alb_dns_name" {
  description = "DNS name of the ALB."
  value       = aws_lb.this.dns_name
}

output "target_group_arn" {
  description = "ARN of the target group the ASG attaches to."
  value       = aws_lb_target_group.this.arn
}

output "app_url" {
  description = "Public HTTPS URL of the application."
  value       = "https://${local.fqdn}"
}
