variable "name" {
  description = "Name prefix for Jenkins resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnets for the Jenkins ALB."
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private app subnets for the Jenkins master and slaves."
  type        = list(string)
}

variable "ami_id" {
  description = "Amazon Linux 2 AMI for Jenkins master/slaves."
  type        = string
}

variable "master_instance_type" {
  description = "Instance type for the Jenkins master."
  type        = string
  default     = "t3.small"
}

variable "slave_instance_type" {
  description = "Instance type for Jenkins slaves."
  type        = string
  default     = "t3.small"
}

variable "slave_count" {
  description = "Number of Jenkins slave/agent instances."
  type        = number
  default     = 2
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

variable "bastion_sg_id" {
  description = "OpenVPN bastion SG allowed to SSH into Jenkins hosts."
  type        = string
}

variable "domain_name" {
  description = "Root domain with an existing Route53 hosted zone."
  type        = string
}

variable "subdomain" {
  description = "Subdomain for Jenkins (e.g. jenkins -> jenkins.example.com)."
  type        = string
  default     = "jenkins"
}

variable "ssl_policy" {
  description = "Jenkins ALB HTTPS listener security policy. Default is TLS 1.3 ONLY."
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-3-2021-06"
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
