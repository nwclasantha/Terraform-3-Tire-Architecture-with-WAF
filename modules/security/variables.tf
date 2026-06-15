variable "name" {
  description = "Name prefix for security groups."
  type        = string
}

variable "vpc_id" {
  description = "VPC in which to create the security groups."
  type        = string
}

variable "admin_cidr" {
  description = "Trusted CIDR allowed to reach the OpenVPN bastion (OpenVPN UI/SSH). Lock this to your office/home IP."
  type        = string
  default     = "0.0.0.0/0"
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
