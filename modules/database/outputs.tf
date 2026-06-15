output "db_private_ip" {
  description = "Private IP of the MySQL instance."
  value       = aws_instance.mysql.private_ip
}

output "db_instance_id" {
  description = "Instance ID of the MySQL server."
  value       = aws_instance.mysql.id
}
