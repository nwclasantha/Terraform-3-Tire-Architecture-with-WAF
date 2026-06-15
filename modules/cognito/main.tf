# Cognito User Pool acts as the broker for OpenVPN logins.
# Primary identity source is Azure AD (O365) via OIDC federation, so users are
# granted / revoked / disabled centrally in Azure AD. A few local "break-glass"
# users can be created for emergencies. OpenVPN authenticates via the OIDC
# Authorization Code flow against the Cognito hosted UI (which redirects to Azure AD).
locals {
  supported_idps = var.azure_enabled ? ["AzureAD"] : ["COGNITO"]
}

resource "aws_cognito_user_pool" "this" {
  name = "${var.name}-vpn-pool"

  username_attributes      = ["email"]
  auto_verified_attributes = ["email"]

  password_policy {
    minimum_length                   = 12
    require_uppercase                = true
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    temporary_password_validity_days = 7
  }

  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  tags = var.tags
}

# Hosted UI domain (the OAuth authorize/token endpoints live here).
resource "aws_cognito_user_pool_domain" "this" {
  domain       = var.hosted_ui_domain_prefix
  user_pool_id = aws_cognito_user_pool.this.id
}

# ----- Azure AD (O365) as an OIDC identity provider -----
resource "aws_cognito_identity_provider" "azure" {
  count = var.azure_enabled ? 1 : 0

  user_pool_id  = aws_cognito_user_pool.this.id
  provider_name = "AzureAD"
  provider_type = "OIDC"

  provider_details = {
    client_id                 = var.azure_client_id
    client_secret             = var.azure_client_secret
    oidc_issuer               = "https://login.microsoftonline.com/${var.azure_tenant_id}/v2.0"
    authorize_scopes          = "openid email profile"
    attributes_request_method = "GET"
  }

  # Map Azure AD claims to Cognito attributes. Only writable pool attributes are valid
  # targets here; "email" is required, and Cognito derives the federated username itself.
  attribute_mapping = {
    email = "email"
  }
}

# App client for the OpenVPN OIDC plugin (Authorization Code flow).
resource "aws_cognito_user_pool_client" "vpn" {
  name         = "${var.name}-vpn-oidc-client"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret = true

  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["openid", "email", "profile"]

  callback_urls = [var.callback_url]
  logout_urls   = [var.logout_url]

  supported_identity_providers = local.supported_idps

  # Also allow admin password auth so break-glass users can be validated server-side.
  explicit_auth_flows = [
    "ALLOW_ADMIN_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
  ]

  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 1

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  depends_on = [aws_cognito_identity_provider.azure]
}

# Optional local break-glass users.
resource "aws_cognito_user" "break_glass" {
  for_each = var.break_glass_users

  user_pool_id       = aws_cognito_user_pool.this.id
  username           = each.key
  temporary_password = each.value.temporary_password

  attributes = {
    email          = each.value.email
    email_verified = "true"
  }

  message_action = "SUPPRESS"
}
