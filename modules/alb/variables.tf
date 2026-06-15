variable "name" {
  description = "Name prefix for ALB resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the target group."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for the internet-facing ALB."
  type        = list(string)
}

variable "alb_sg_id" {
  description = "Security group ID for the ALB."
  type        = string
}

variable "domain_name" {
  description = "Root domain with an existing Route53 hosted zone (e.g. example.com)."
  type        = string
}

variable "subdomain" {
  description = "Subdomain to expose the app on (e.g. app -> app.example.com)."
  type        = string
}

variable "health_check_path" {
  description = "Target group health check path."
  type        = string
  default     = "/"
}

variable "ssl_policy" {
  description = "ALB HTTPS listener security policy. Default is TLS 1.3 ONLY."
  type        = string
  default     = "ELBSecurityPolicy-TLS13-1-3-2021-06"
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
