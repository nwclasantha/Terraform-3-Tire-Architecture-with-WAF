# ----------------------------- Global -----------------------------
variable "project" {
  description = "Project name / resource name prefix."
  type        = string
  default     = "amelys"
}

variable "region" {
  description = "AWS region."
  type        = string
  default     = "us-east-1"
}

# ----------------------------- Network -----------------------------
variable "vpc_cidr" {
  description = "CIDR for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "azs" {
  description = "Two availability zones."
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "Public (ALB) subnet CIDRs."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_app_subnet_cidrs" {
  description = "Private application (web/CI) subnet CIDRs."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "private_db_subnet_cidrs" {
  description = "Private database subnet CIDRs."
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24"]
}

# ----------------------------- DNS / TLS -----------------------------
variable "domain_name" {
  description = "Root domain with an existing Route53 public hosted zone (e.g. example.com)."
  type        = string
}

variable "app_subdomain" {
  description = "Subdomain for the web app."
  type        = string
  default     = "app"
}

variable "jenkins_subdomain" {
  description = "Subdomain for Jenkins."
  type        = string
  default     = "jenkins"
}

# ----------------------------- AMIs -----------------------------
variable "amazon_linux_ami" {
  description = "Amazon Linux 2 AMI (web, db, jenkins)."
  type        = string
  default     = "ami-03ededff12e34e59e"
}

variable "ubuntu_ami" {
  description = "Ubuntu 22.04 AMI (OpenVPN bastion)."
  type        = string
  default     = "ami-0c7217cdde317cfec"
}

# ----------------------------- Instance sizing -----------------------------
variable "web_instance_type" {
  description = "Web tier instance type."
  type        = string
  default     = "t3.micro"
}

variable "db_instance_type" {
  description = "DB instance type."
  type        = string
  default     = "t3.micro"
}

variable "bastion_instance_type" {
  description = "OpenVPN bastion instance type."
  type        = string
  default     = "t3.micro"
}

variable "jenkins_master_instance_type" {
  description = "Jenkins master instance type."
  type        = string
  default     = "t3.small"
}

variable "jenkins_slave_instance_type" {
  description = "Jenkins slave instance type."
  type        = string
  default     = "t3.small"
}

variable "jenkins_slave_count" {
  description = "Number of Jenkins slaves."
  type        = number
  default     = 2
}

# ----------------------------- ASG -----------------------------
variable "asg_min_size" {
  type    = number
  default = 2
}

variable "asg_desired_capacity" {
  type    = number
  default = 2
}

variable "asg_max_size" {
  type    = number
  default = 4
}

# ----------------------------- Database creds -----------------------------
variable "db_name" {
  description = "Application database name."
  type        = string
  default     = "appdb"
}

variable "db_username" {
  description = "Application database user."
  type        = string
  default     = "appuser"
}

variable "db_password" {
  description = "Application database password. Override with TF_VAR_db_password."
  type        = string
  sensitive   = true
}

# ----------------------------- Access / SSH -----------------------------
variable "key_name" {
  description = "Optional EC2 key pair name for SSH-over-VPN. Empty disables SSH keys."
  type        = string
  default     = ""
}

variable "admin_cidr" {
  description = "Trusted CIDR allowed to reach the OpenVPN admin/SSH (lock to your IP)."
  type        = string
  default     = "0.0.0.0/0"
}

# ----------------------------- WAF -----------------------------
variable "waf_blacklist_ips" {
  description = "IPv4 CIDRs to block at the WAF."
  type        = list(string)
  default     = []
}

# ----------------------------- Logging -----------------------------
variable "flow_log_retention_days" {
  description = "CloudWatch flow-log retention (days)."
  type        = number
  default     = 90
}

# ----------------------------- Cognito / Azure AD -----------------------------
variable "cognito_hosted_ui_prefix" {
  description = "Globally-unique prefix for the Cognito hosted UI domain."
  type        = string
}

variable "azure_enabled" {
  description = "Federate OpenVPN logins with Azure AD (O365)."
  type        = bool
  default     = true
}

variable "azure_tenant_id" {
  description = "Azure AD tenant (directory) ID."
  type        = string
  default     = ""
}

variable "azure_client_id" {
  description = "Azure AD app registration client ID."
  type        = string
  default     = ""
}

variable "azure_client_secret" {
  description = "Azure AD app registration client secret. Override with TF_VAR_azure_client_secret."
  type        = string
  default     = ""
  sensitive   = true
}

variable "break_glass_users" {
  description = "Optional local Cognito users for emergencies."
  type = map(object({
    email              = string
    temporary_password = string
  }))
  default = {}
}
