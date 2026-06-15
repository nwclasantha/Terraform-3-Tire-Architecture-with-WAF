variable "name" {
  description = "Name prefix for compute resources."
  type        = string
}

variable "subnet_ids" {
  description = "Private application subnet IDs for the ASG."
  type        = list(string)
}

variable "web_sg_id" {
  description = "Security group ID for the web tier."
  type        = string
}

variable "target_group_arn" {
  description = "ALB target group ARN to register instances with."
  type        = string
}

variable "ami_id" {
  description = "AMI ID for web instances (Amazon Linux 2)."
  type        = string
}

variable "instance_type" {
  description = "Instance type for web instances."
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

variable "min_size" {
  description = "ASG minimum size."
  type        = number
  default     = 2
}

variable "desired_capacity" {
  description = "ASG desired capacity."
  type        = number
  default     = 2
}

variable "max_size" {
  description = "ASG maximum size."
  type        = number
  default     = 4
}

variable "aws_region" {
  description = "AWS region (used by the bootstrap to call Secrets Manager)."
  type        = string
}

variable "db_secret_name" {
  description = "Secrets Manager secret ID holding the DB connection details."
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
