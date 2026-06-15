output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public (ALB) subnets."
  value       = aws_subnet.public[*].id
}

output "private_app_subnet_ids" {
  description = "IDs of the private application (web tier) subnets."
  value       = aws_subnet.private_app[*].id
}

output "private_db_subnet_ids" {
  description = "IDs of the private database subnets."
  value       = aws_subnet.private_db[*].id
}

output "private_app_subnet_cidrs" {
  description = "CIDRs of the private application subnets."
  value       = aws_subnet.private_app[*].cidr_block
}
