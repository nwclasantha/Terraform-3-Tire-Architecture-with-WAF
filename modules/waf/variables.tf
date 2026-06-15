variable "name" {
  description = "Name prefix for WAF resources."
  type        = string
}

variable "resource_arns" {
  description = "ARNs of the ALB(s) to associate this Web ACL with (e.g. app ALB and Jenkins ALB)."
  type        = list(string)
}

variable "blacklist_ips" {
  description = "IPv4 CIDRs to block outright."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
