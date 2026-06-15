output "user_pool_id" {
  description = "Cognito User Pool ID."
  value       = aws_cognito_user_pool.this.id
}

output "user_pool_arn" {
  description = "Cognito User Pool ARN (for IAM scoping)."
  value       = aws_cognito_user_pool.this.arn
}

output "vpn_client_id" {
  description = "Cognito app client ID used by the OpenVPN OIDC plugin."
  value       = aws_cognito_user_pool_client.vpn.id
}

output "vpn_client_secret" {
  description = "Cognito app client secret for the OpenVPN OIDC plugin."
  value       = aws_cognito_user_pool_client.vpn.client_secret
  sensitive   = true
}

output "hosted_ui_domain" {
  description = "Cognito hosted UI domain (OIDC issuer base for the VPN)."
  value       = "https://${aws_cognito_user_pool_domain.this.domain}.auth.${data.aws_region.current.name}.amazoncognito.com"
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for the user pool (used by openvpn-auth-oauth2)."
  value       = "https://cognito-idp.${data.aws_region.current.name}.amazonaws.com/${aws_cognito_user_pool.this.id}"
}

data "aws_region" "current" {}
