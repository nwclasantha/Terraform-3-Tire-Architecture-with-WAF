variable "name" {
  description = "Name prefix for KMS keys/aliases."
  type        = string
}

variable "tags" {
  description = "Common tags."
  type        = map(string)
  default     = {}
}
