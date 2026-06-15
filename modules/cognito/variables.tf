variable "name" {
  description = "Name prefix for Cognito resources."
  type        = string
}

variable "hosted_ui_domain_prefix" {
  description = "Globally-unique prefix for the Cognito hosted UI domain (e.g. acme-vpn)."
  type        = string
}

variable "callback_url" {
  description = "OAuth callback URL the OpenVPN OIDC plugin listens on (e.g. http://localhost:9000/oauth2/callback)."
  type        = string
  default     = "http://localhost:9000/oauth2/callback"
}

variable "logout_url" {
  description = "OAuth logout redirect URL."
  type        = string
  default     = "http://localhost:9000/"
}

# ----- Azure AD (O365) OIDC federation -----
variable "azure_enabled" {
  description = "Whether to federate the user pool with Azure AD (O365) via OIDC."
  type        = bool
  default     = true
}

variable "azure_tenant_id" {
  description = "Azure AD tenant ID (directory ID)."
  type        = string
  default     = ""
}

variable "azure_client_id" {
  description = "Application (client) ID of the Azure AD app registration for VPN SSO."
  type        = string
  default     = ""
}

variable "azure_client_secret" {
  description = "Client secret of the Azure AD app registration."
  type        = string
  default     = ""
  sensitive   = true
}

# ----- Optional local break-glass users (used if Azure AD is unreachable) -----
variable "break_glass_users" {
  description = "Optional local Cognito users for emergencies. Key=username, value={email, temporary_password}."
  type = map(object({
    email              = string
    temporary_password = string
  }))
  default = {}
}

variable "tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
  default     = {}
}
