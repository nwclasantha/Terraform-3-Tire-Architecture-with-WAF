output "asg_name" {
  description = "Name of the web tier Auto Scaling Group."
  value       = aws_autoscaling_group.web.name
}

output "launch_template_id" {
  description = "ID of the web tier launch template."
  value       = aws_launch_template.web.id
}
