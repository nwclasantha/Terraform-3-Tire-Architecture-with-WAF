variable "name" {
  description = "Name prefix for the secret."
  type        = string
}

variable "db_host" {
  description = "Database host (private IP/DNS) to store in the connection secret."
  type        = string
}

variable "db_port" {
  description = "Database port."
  type        = number
  default     = 3306
}

variable "db_name" {
  description = "Database name."
  type        = string
}

variable "db_username" {
  description = "Database username."
  type        = string
}

variable "db_password" {
  description = "Database password."
  type        = string
  sensitive   = true
}

variable "recovery_window_days" {
  description = "Days before a deleted secret is permanently removed (0 = delete immediately)."
  type        = number
  default     = 7
}

variable "kms_key_arn" {
  description = "CMK ARN used to encrypt the secret."
  type        = string
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
