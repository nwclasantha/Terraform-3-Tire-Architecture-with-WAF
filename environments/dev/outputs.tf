output "app_url" {
  description = "Public HTTPS URL of the web application."
  value       = module.alb.app_url
}

output "app_alb_dns_name" {
  description = "App ALB DNS name."
  value       = module.alb.alb_dns_name
}

output "jenkins_url" {
  description = "Public HTTPS URL of Jenkins."
  value       = module.jenkins.jenkins_url
}

output "openvpn_public_ip" {
  description = "Elastic IP of the OpenVPN server."
  value       = module.bastion.public_ip
}

output "vpn_profiles_bucket" {
  description = "S3 bucket holding generated .ovpn client profiles."
  value       = module.bastion.profiles_bucket
}

output "waf_web_acl_arn" {
  description = "ARN of the WAFv2 Web ACL protecting both ALBs."
  value       = module.waf.web_acl_arn
}

output "flow_logs_bucket" {
  description = "Private S3 bucket holding VPC flow logs for SOC."
  value       = module.logging.flow_logs_bucket_name
}

output "flow_logs_log_group" {
  description = "CloudWatch log group for VPC flow logs."
  value       = module.logging.log_group_name
}

output "db_private_ip" {
  description = "Private IP of the MySQL server."
  value       = module.database.db_private_ip
}

output "cognito_user_pool_id" {
  description = "Cognito user pool ID for OpenVPN SSO."
  value       = module.cognito.user_pool_id
}

output "cognito_hosted_ui_domain" {
  description = "Cognito hosted UI domain."
  value       = module.cognito.hosted_ui_domain
}
