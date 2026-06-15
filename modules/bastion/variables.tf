variable "name" {
  description = "Name prefix for bastion resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID."
  type        = string
}

variable "public_subnet_id" {
  description = "Public subnet to launch the OpenVPN server in."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR pushed as a route to VPN clients."
  type        = string
}

variable "bastion_sg_id" {
  description = "Security group ID for the OpenVPN bastion."
  type        = string
}

variable "ami_id" {
  description = "Ubuntu 22.04 AMI ID for the OpenVPN server."
  type        = string
}

variable "instance_type" {
  description = "Instance type for the OpenVPN server."
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Optional EC2 key pair for SSH admin (empty to disable)."
  type        = string
  default     = ""
}

variable "aws_region" {
  description = "AWS region (used by the bootstrap script)."
  type        = string
}

# ----- OIDC (Cognito/Azure AD) inputs for OpenVPN SSO -----
variable "oidc_issuer" {
  description = "OIDC issuer URL of the Cognito user pool."
  type        = string
}

variable "oidc_client_id" {
  description = "Cognito app client ID for the OpenVPN OIDC plugin."
  type        = string
}

variable "oidc_client_secret" {
  description = "Cognito app client secret for the OpenVPN OIDC plugin."
  type        = string
  sensitive   = true
}

variable "cognito_user_pool_arn" {
  description = "Cognito user pool ARN, used to scope the AdminInitiateAuth IAM permission."
  type        = string
}

variable "kms_key_arn" {
  description = "CMK ARN used to encrypt the VPN profiles bucket."
  type        = string
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
