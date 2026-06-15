variable "name" {
  description = "Name prefix for logging resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC whose traffic will be captured by flow logs."
  type        = string
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention in days."
  type        = number
  default     = 90
}

variable "kms_key_arn" {
  description = "CMK ARN to encrypt the CloudWatch log group and flow-logs S3 bucket."
  type        = string
}

variable "s3_retention_days" {
  description = "Days to keep flow logs in S3 before expiration (SOC retention)."
  type        = number
  default     = 365
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
