variable "name" {
  description = "Name prefix for database resources."
  type        = string
}

variable "subnet_id" {
  description = "Private DB subnet to launch the MySQL instance in."
  type        = string
}

variable "db_sg_id" {
  description = "Security group ID for the database instance."
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the MySQL instance (Amazon Linux 2)."
  type        = string
}

variable "instance_type" {
  description = "Instance type for the MySQL server."
  type        = string
  default     = "t3.micro"
}

variable "instance_profile_name" {
  description = "IAM instance profile (for SSM access)."
  type        = string
}

variable "key_name" {
  description = "Optional EC2 key pair for SSH-over-VPN admin (empty to disable)."
  type        = string
  default     = ""
}

variable "db_name" {
  description = "Application database name."
  type        = string
}

variable "db_username" {
  description = "Application database username."
  type        = string
}

variable "db_password" {
  description = "Application database password."
  type        = string
  sensitive   = true
}

variable "app_cidr" {
  description = "MySQL host pattern allowed to connect as the app DB user (e.g. 10.0.%)."
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
