output "alb_sg_id" {
  description = "Security group ID for the ALB."
  value       = aws_security_group.alb.id
}

output "web_sg_id" {
  description = "Security group ID for the web tier."
  value       = aws_security_group.web.id
}

output "db_sg_id" {
  description = "Security group ID for the database tier."
  value       = aws_security_group.db.id
}

output "bastion_sg_id" {
  description = "Security group ID for the OpenVPN bastion."
  value       = aws_security_group.bastion.id
}
