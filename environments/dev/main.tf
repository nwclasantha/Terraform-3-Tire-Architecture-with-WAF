locals {
  name = var.project
  tags = {
    Project = var.project
    Stack   = "3-tier-waf"
  }
  # MySQL host pattern for the app user grant (derived from the VPC's first two octets,
  # e.g. 10.0.0.0/16 -> "10.0.%"). MySQL needs a wildcard host, not CIDR notation.
  vpc_octets        = split(".", split("/", var.vpc_cidr)[0])
  app_cidr_supernet = "${local.vpc_octets[0]}.${local.vpc_octets[1]}.%"
}

# ----------------------------- Networking -----------------------------
module "vpc" {
  source = "../../modules/vpc"

  name                     = local.name
  vpc_cidr                 = var.vpc_cidr
  azs                      = var.azs
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs
  tags                     = local.tags
}

# ----------------------------- KMS customer-managed keys -----------------------------
module "kms" {
  source = "../../modules/kms"

  name = local.name
  tags = local.tags
}

# ----------------------------- VPC flow logs (CW + S3 SOC) -----------------------------
module "logging" {
  source = "../../modules/logging"

  name               = local.name
  vpc_id             = module.vpc.vpc_id
  log_retention_days = var.flow_log_retention_days
  kms_key_arn        = module.kms.logs_key_arn
  tags               = local.tags
}

# ----------------------------- Security groups -----------------------------
module "security" {
  source = "../../modules/security"

  name       = local.name
  vpc_id     = module.vpc.vpc_id
  admin_cidr = var.admin_cidr
  tags       = local.tags
}

# ----------------------------- App ALB (HTTPS only) -----------------------------
module "alb" {
  source = "../../modules/alb"

  name              = local.name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  alb_sg_id         = module.security.alb_sg_id
  domain_name       = var.domain_name
  subdomain         = var.app_subdomain
  tags              = local.tags
}

# ----------------------------- MySQL on EC2 (private) -----------------------------
module "database" {
  source = "../../modules/database"

  name                  = local.name
  subnet_id             = module.vpc.private_db_subnet_ids[0]
  db_sg_id              = module.security.db_sg_id
  ami_id                = var.amazon_linux_ami
  instance_type         = var.db_instance_type
  instance_profile_name = aws_iam_instance_profile.ssm.name
  key_name              = var.key_name
  db_name               = var.db_name
  db_username           = var.db_username
  db_password           = var.db_password
  app_cidr              = local.app_cidr_supernet
  tags                  = local.tags
}

# ----------------------------- DB connection secret -----------------------------
module "secrets" {
  source = "../../modules/secrets"

  name        = local.name
  db_host     = module.database.db_private_ip
  db_port     = 3306
  db_name     = var.db_name
  db_username = var.db_username
  db_password = var.db_password
  kms_key_arn = module.kms.data_key_arn
  tags        = local.tags
}

# ----------------------------- Web tier (Auto Scaling) -----------------------------
module "compute" {
  source = "../../modules/compute"

  name                  = local.name
  subnet_ids            = module.vpc.private_app_subnet_ids
  web_sg_id             = module.security.web_sg_id
  target_group_arn      = module.alb.target_group_arn
  ami_id                = var.amazon_linux_ami
  instance_type         = var.web_instance_type
  instance_profile_name = aws_iam_instance_profile.web.name
  key_name              = var.key_name
  min_size              = var.asg_min_size
  desired_capacity      = var.asg_desired_capacity
  max_size              = var.asg_max_size
  aws_region            = var.region
  db_secret_name        = module.secrets.secret_name
  tags                  = local.tags
}

# ----------------------------- Cognito + Azure AD (OpenVPN SSO) -----------------------------
module "cognito" {
  source = "../../modules/cognito"

  name                    = local.name
  hosted_ui_domain_prefix = var.cognito_hosted_ui_prefix
  azure_enabled           = var.azure_enabled
  azure_tenant_id         = var.azure_tenant_id
  azure_client_id         = var.azure_client_id
  azure_client_secret     = var.azure_client_secret
  break_glass_users       = var.break_glass_users
  tags                    = local.tags
}

# ----------------------------- OpenVPN bastion -----------------------------
module "bastion" {
  source = "../../modules/bastion"

  name                  = local.name
  vpc_id                = module.vpc.vpc_id
  public_subnet_id      = module.vpc.public_subnet_ids[0]
  vpc_cidr              = var.vpc_cidr
  bastion_sg_id         = module.security.bastion_sg_id
  ami_id                = var.ubuntu_ami
  instance_type         = var.bastion_instance_type
  key_name              = var.key_name
  aws_region            = var.region
  oidc_issuer           = module.cognito.oidc_issuer_url
  oidc_client_id        = module.cognito.vpn_client_id
  oidc_client_secret    = module.cognito.vpn_client_secret
  cognito_user_pool_arn = module.cognito.user_pool_arn
  kms_key_arn           = module.kms.data_key_arn
  tags                  = local.tags
}

# ----------------------------- Jenkins (CI behind ALB + WAF) -----------------------------
module "jenkins" {
  source = "../../modules/jenkins"

  name                  = local.name
  vpc_id                = module.vpc.vpc_id
  public_subnet_ids     = module.vpc.public_subnet_ids
  private_subnet_ids    = module.vpc.private_app_subnet_ids
  ami_id                = var.amazon_linux_ami
  master_instance_type  = var.jenkins_master_instance_type
  slave_instance_type   = var.jenkins_slave_instance_type
  slave_count           = var.jenkins_slave_count
  instance_profile_name = aws_iam_instance_profile.ssm.name
  key_name              = var.key_name
  bastion_sg_id         = module.security.bastion_sg_id
  domain_name           = var.domain_name
  subdomain             = var.jenkins_subdomain
  tags                  = local.tags
}

# ----------------------------- WAF (protects app ALB + Jenkins ALB) -----------------------------
module "waf" {
  source = "../../modules/waf"

  name          = local.name
  resource_arns = [module.alb.alb_arn, module.jenkins.jenkins_alb_arn]
  blacklist_ips = var.waf_blacklist_ips
  tags          = local.tags
}
