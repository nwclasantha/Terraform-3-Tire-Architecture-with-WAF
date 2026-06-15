output "jenkins_alb_arn" {
  description = "ARN of the Jenkins ALB (associate with the shared WAF)."
  value       = aws_lb.jenkins.arn
}

output "jenkins_url" {
  description = "Public HTTPS URL of Jenkins."
  value       = "https://${local.fqdn}"
}

output "master_private_ip" {
  description = "Private IP of the Jenkins master."
  value       = aws_instance.master.private_ip
}

output "slave_private_ips" {
  description = "Private IPs of the Jenkins slaves."
  value       = aws_instance.slave[*].private_ip
}
