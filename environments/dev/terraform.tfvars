# ----------------------------- Example configuration -----------------------------
# Copy/adjust values. Secrets (db_password, azure_client_secret) should be supplied
# via environment variables instead of this file:
#   export TF_VAR_db_password='...'  (PowerShell: $env:TF_VAR_db_password='...')
#   export TF_VAR_azure_client_secret='...'

project = "amelys"
region  = "us-east-1"

# --- DNS / TLS (must be a Route53 PUBLIC hosted zone you own) ---
domain_name       = "example.com"
app_subdomain     = "app"
jenkins_subdomain = "jenkins"

# --- AMIs (us-east-1 examples; replace with current AMIs) ---
amazon_linux_ami = "ami-03ededff12e34e59e"
ubuntu_ami       = "ami-0c7217cdde317cfec"

# --- Sizing ---
web_instance_type            = "t3.micro"
db_instance_type             = "t3.micro"
bastion_instance_type        = "t3.micro"
jenkins_master_instance_type = "t3.small"
jenkins_slave_instance_type  = "t3.small"
jenkins_slave_count          = 2

asg_min_size         = 2
asg_desired_capacity = 2
asg_max_size         = 4

# --- Database (override db_password via TF_VAR_db_password) ---
db_name     = "appdb"
db_username = "appuser"
# db_password = "set-me-via-env-var"

# --- Access ---
# Lock this down to your office/VPN egress IP/32 in production.
admin_cidr = "0.0.0.0/0"
key_name   = ""

# --- WAF ---
waf_blacklist_ips = ["1.2.3.4/32", "5.6.7.8/32"]

# --- VPC flow logs ---
flow_log_retention_days = 90

# --- Cognito hosted UI (must be globally unique) ---
cognito_hosted_ui_prefix = "amelys-vpn-sso"

# --- Azure AD (O365) federation for OpenVPN ---
azure_enabled   = true
azure_tenant_id = "00000000-0000-0000-0000-000000000000"
azure_client_id = "00000000-0000-0000-0000-000000000000"
# azure_client_secret = "set-me-via-env-var"

# --- Optional break-glass local VPN users ---
break_glass_users = {
  # "breakglass" = { email = "soc@example.com", temporary_password = "ChangeMe!2026Aa" }
}
