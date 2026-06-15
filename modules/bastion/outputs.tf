output "public_ip" {
  description = "Public Elastic IP of the OpenVPN server."
  value       = aws_eip.openvpn.public_ip
}

output "profiles_bucket" {
  description = "S3 bucket holding generated .ovpn client profiles."
  value       = aws_s3_bucket.profiles.id
}

output "instance_id" {
  description = "Instance ID of the OpenVPN server."
  value       = aws_instance.openvpn.id
}
