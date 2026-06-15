variable "name" {
  description = "Name prefix for all VPC resources."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Availability zones to spread subnets across (exactly 2)."
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDRs for the public (ALB) subnets, one per AZ."
  type        = list(string)
}

variable "private_app_subnet_cidrs" {
  description = "CIDRs for the private application (web/ASG) subnets, one per AZ."
  type        = list(string)
}

variable "private_db_subnet_cidrs" {
  description = "CIDRs for the private database subnets, one per AZ."
  type        = list(string)
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
