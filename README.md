# Secure 3-Tier Web Platform on AWS — WAF, CI/CD, Zero-Trust Admin (Terraform)

A fully automated, modular Terraform stack that provisions a hardened 3-tier application
platform with edge WAF protection, TLS 1.3, an Auto Scaling web tier, a private MySQL
database, secrets in AWS Secrets Manager, CI/CD via Jenkins, zero-trust admin access via
OpenVPN federated to Azure AD (O365), KMS encryption everywhere, and VPC flow logs shipped
to both CloudWatch and a private S3 bucket for SOC.

**Status:** `terraform validate` ✅ · `terraform fmt` ✅ · `tfsec` ✅ 0 findings.

![Animated architecture flow](docs/architecture-flow.gif)

> Animated data-flow diagram (`docs/architecture-flow.gif`) — glowing packets show the
> encrypted control/data paths between every component. Regenerate with
> `python docs/make_gif.py`.

---

## Table of contents
1. [Architecture](#1-architecture)
2. [Component map](#2-component-map)
3. [Repository layout](#3-repository-layout)
4. [Prerequisites (A→Z)](#4-prerequisites-az)
5. [Configuration / variables](#5-configuration--variables)
6. [Deploy step by step](#6-deploy-step-by-step)
7. [Post-deploy configuration](#7-post-deploy-configuration)
8. [How access works](#8-how-access-works)
9. [Verification](#9-verification)
10. [Security model](#10-security-model)
11. [Day-2 operations](#11-day-2-operations)
12. [Teardown](#12-teardown)
13. [Troubleshooting](#13-troubleshooting)

---

## 1. Architecture

```
                                   ┌────────────────────┐
                                   │   Azure AD (O365)   │  identity source
                                   └─────────▲──────────┘  (grant/revoke/disable)
                                             │ OIDC federation
                                   ┌─────────┴──────────┐
                                   │   AWS Cognito      │  broker + hosted UI
                                   └─────────▲──────────┘
                                             │ OIDC SSO
                              Internet       │
                                 │           │
        ┌────────────────────────┼───────────┼──────────────────────────────┐
        │ Public subnets         │           │                              │
        │   ┌────────────────────▼───┐   ┌───┴──────────────┐               │
        │   │  AWS WAFv2 (REGIONAL)  │   │  OpenVPN bastion │  EIP, TLS     │
        │   │  free managed rules    │   │  (OIDC login)    │  tunnel→VPC   │
        │   └──────┬──────────┬──────┘   └───────┬──────────┘               │
        │   443 only│          │443 only          │ admin (SSH/MySQL)        │
        │  80→301   │          │80→301            │                          │
        │   ┌───────▼──┐   ┌───▼────────┐         │                          │
        │   │ App ALB  │   │ Jenkins ALB│         │                          │
        │   │ TLS 1.3  │   │ TLS 1.3    │         │                          │
        │   └────┬─────┘   └─────┬──────┘         │                          │
        └────────┼───────────────┼────────────────┼──────────────────────────┘
                 │ forward 80     │ forward 8080    │
        ┌────────▼───────┐ ┌──────▼───────┐ ┌──────▼────────┐  Private app subnets
        │ Web tier ASG   │ │Jenkins master│ │ Jenkins slaves│
        │ (Apache/PHP)   │ └──────────────┘ │ (build/deploy)│
        │ reads secret ◄─┼─ Secrets Manager (CMK)            │
        └────────┬───────┘                  └───────────────┘
                 │ 3306 (private, SG-restricted)
        ┌────────▼───────┐  Private DB subnets
        │ MySQL on EC2   │  (no public IP)
        └────────────────┘

   Egress: private subnets → NAT gateway → Internet
   Observability: VPC Flow Logs → CloudWatch Logs (CMK) + private S3 bucket (CMK, SOC)
   Encryption at rest: KMS CMKs (rotating) for secrets, logs, and log/profile buckets
```

**Network tiers**
- **Public subnets** (2 AZs): App ALB, Jenkins ALB, NAT gateway, OpenVPN bastion.
- **Private app subnets** (2 AZs): Web ASG, Jenkins master + slaves. Egress via NAT.
- **Private DB subnets** (2 AZs): MySQL EC2 only. No public IP.

---

## 2. Component map

| Module | Provisions |
|---|---|
| `vpc` | VPC, 2 public + 2 private-app + 2 private-db subnets, IGW, NAT GW (+EIP), route tables |
| `kms` | Two rotating customer-managed keys: `logs` (CW + flow S3) and `data` (secrets + profiles S3) |
| `logging` | VPC Flow Logs → CloudWatch (CMK) **and** → private S3 (CMK, versioned, public-blocked) for SOC |
| `security` | Least-privilege SGs: ALB, web, DB, bastion (+ admin rules); no internet SSH |
| `alb` | Internet-facing ALB, ACM cert (DNS-validated), **443 (TLS 1.3 only)**, **80→443 redirect**, Route53 alias |
| `waf` | WAFv2 Web ACL (Common, KnownBadInputs, Linux, AmazonIpReputation + IP blacklist), associated to both ALBs |
| `database` | MySQL (MariaDB) on a private EC2, encrypted EBS, IMDSv2, no public IP |
| `secrets` | DB connection secret in Secrets Manager (CMK) |
| `compute` | Launch template + Auto Scaling Group (web tier) + CPU target-tracking; reads secret via instance role |
| `cognito` | Cognito user pool + hosted UI + Azure AD OIDC IdP + optional break-glass users |
| `bastion` | OpenVPN EC2 (EIP), OIDC SSO, profiles S3 bucket (CMK, versioned), scoped IAM |
| `jenkins` | Jenkins master behind its own ALB+WAF (TLS 1.3) + N build slaves, own SGs |

---

## 3. Repository layout

```
3-Tire_with_waf-WORKED/
├── modules/
│   ├── vpc/  kms/  logging/  security/  alb/  waf/
│   ├── database/  secrets/  compute/
│   └── cognito/  bastion/  jenkins/          # each: main.tf, variables.tf, outputs.tf
├── environments/
│   └── dev/
│       ├── versions.tf      # terraform + provider constraints
│       ├── providers.tf     # aws provider + default_tags
│       ├── variables.tf     # all inputs
│       ├── iam.tf           # shared SSM role + dedicated web role (secret read)
│       ├── main.tf          # wires all 12 modules
│       ├── outputs.tf       # URLs, IPs, bucket names, IDs
│       └── terraform.tfvars # example values (edit before apply)
├── scripts/
│   ├── install_apache.sh         # web tier (fetches secret from Secrets Manager)
│   ├── install_mysql.sh          # MySQL server
│   ├── install_openvpn.sh        # OpenVPN + OIDC (Cognito/Azure AD)
│   ├── install_jenkins_master.sh # Jenkins master
│   └── install_jenkins_slave.sh  # Jenkins build agent
└── README.md
```

---

## 4. Prerequisites (A→Z)

**A. Tooling**
- Terraform >= 1.5 (tested with 1.15.6).
- AWS CLI v2, authenticated (`aws configure`, SSO, or env vars) with rights to create the resources below.
- (Optional, recommended) `tfsec`/Trivy for re-scanning.

**B. AWS account**
- A region (default `us-east-1`). ACM certs for an ALB **must** be in the same region as the ALB.
- Service quotas for: 2 ALBs, ~6+ EC2 instances, 1 NAT GW, 2 KMS keys, 1 VPC.

**C. DNS — a public Route53 hosted zone you own**
- The `alb` and `jenkins` modules look up the zone by `domain_name` and create:
  - ACM DNS-validation records
  - `app.<domain>` and `jenkins.<domain>` alias records
- If you don't have one: register/transfer a domain into Route53 (or delegate an existing domain's NS to a Route53 public hosted zone) **before** applying.

**D. Azure AD (O365) app registration — for OpenVPN SSO**
1. Azure Portal → *Microsoft Entra ID* → *App registrations* → *New registration*.
2. Add a **Web** redirect URI:
   `https://<cognito_hosted_ui_prefix>.auth.<region>.amazoncognito.com/oauth2/idpresponse`
3. *Certificates & secrets* → create a **client secret**.
4. Record: **Directory (tenant) ID**, **Application (client) ID**, **client secret**.
5. Under *API permissions*, ensure `openid`, `email`, `profile` (Microsoft Graph delegated) are granted.

**E. AMIs**
- Amazon Linux 2 AMI (web/db/jenkins) and Ubuntu 22.04 AMI (OpenVPN), valid in your region.
  Replace the example IDs in `terraform.tfvars` with current ones.

---

## 5. Configuration / variables

Edit `environments/dev/terraform.tfvars`. Key variables:

| Variable | Purpose | Notes |
|---|---|---|
| `project`, `region` | Name prefix + region | |
| `vpc_cidr`, `azs`, `*_subnet_cidrs` | Network sizing | one CIDR per AZ |
| `domain_name` | Route53 public zone you own | **required** |
| `app_subdomain`, `jenkins_subdomain` | App + Jenkins hostnames | default `app`, `jenkins` |
| `amazon_linux_ami`, `ubuntu_ami` | AMIs | replace with current IDs |
| `*_instance_type`, `asg_*`, `jenkins_slave_count` | Sizing | |
| `db_name`, `db_username` | DB identifiers | |
| `db_password` | DB password | **set via `TF_VAR_db_password`** (sensitive) |
| `cognito_hosted_ui_prefix` | Cognito hosted-UI domain | **globally unique** |
| `azure_enabled`, `azure_tenant_id`, `azure_client_id` | Azure AD federation | |
| `azure_client_secret` | Azure AD secret | **set via `TF_VAR_azure_client_secret`** |
| `admin_cidr` | Trusted CIDR for OpenVPN admin/SSH | lock to your `/32` |
| `waf_blacklist_ips` | IPs to block at WAF | |
| `flow_log_retention_days` | CloudWatch retention | |
| `break_glass_users` | Optional local VPN users | emergencies only |

**Never** put secrets in `terraform.tfvars`. Use environment variables:

```bash
# bash
export TF_VAR_db_password='<strong-password>'
export TF_VAR_azure_client_secret='<azure-app-secret>'
```
```powershell
# PowerShell
$env:TF_VAR_db_password='<strong-password>'
$env:TF_VAR_azure_client_secret='<azure-app-secret>'
```

---

## 6. Deploy step by step

```bash
# 1. Go to the environment root
cd environments/dev

# 2. Provide secrets via env vars (see section 5)
export TF_VAR_db_password='...'
export TF_VAR_azure_client_secret='...'

# 3. Edit terraform.tfvars — at minimum:
#    domain_name, cognito_hosted_ui_prefix, azure_tenant_id/client_id, AMIs, admin_cidr

# 4. Initialize providers/modules
terraform init

# 5. Format + validate
terraform fmt -recursive
terraform validate

# 6. (Recommended) security scan
tfsec ..          # or: trivy config ..

# 7. Review the plan
terraform plan

# 8. Apply
terraform apply
```

**Apply ordering** is handled by Terraform's dependency graph:
`vpc → kms → logging/security → alb/database → secrets → waf/compute → cognito → bastion → jenkins`.
ACM validation gates the 443 listeners, so the first apply may take several minutes while
DNS validation completes.

After apply, note the outputs:
```bash
terraform output
# app_url, jenkins_url, openvpn_public_ip, vpn_profiles_bucket,
# waf_web_acl_arn, flow_logs_bucket, db_private_ip, cognito_*
```

---

## 7. Post-deploy configuration

**Jenkins (first login)**
```bash
aws ssm start-session --target <jenkins-master-instance-id>
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```
Open `https://jenkins.<domain>`, complete setup, then register the slave nodes
(Manage Jenkins → Nodes) using the private IPs from `terraform output`.

**OpenVPN client (developers)**
```bash
aws s3 cp s3://<vpn_profiles_bucket>/profiles/client-sso.ovpn .
# Import client-sso.ovpn into the OpenVPN client; on connect you'll be sent
# through Cognito → Azure AD login. Only valid Azure AD users complete the handshake.
```

**Azure AD redirect URI** — confirm it exactly matches:
`https://<cognito_hosted_ui_prefix>.auth.<region>.amazoncognito.com/oauth2/idpresponse`

---

## 8. How access works

**Regular / mandatory releases → Jenkins (the only sanctioned release path)**
Pipelines run on the **slave/agent** EC2s in the private subnets; agents deploy to the web/DB
tiers. Jenkins master/UI sits behind its own ALB + WAF (TLS 1.3).

**Urgent / ad-hoc access → OpenVPN (Azure-AD-gated)**
1. Grant/revoke/disable the user centrally in **Azure AD (O365)**.
2. Approved dev connects with the SSO profile → OIDC → Cognito → Azure AD.
3. Over the tunnel the dev can `scp`/`sftp` to the web/DB servers to manage incidents.

**Host administration → SSM Session Manager** (no inbound SSH from the internet anywhere).

---

## 9. Verification

| Check | Expected |
|---|---|
| `https://app.<domain>` | Apache page served, **valid TLS 1.3 cert** |
| `http://app.<domain>` | **301 redirect** to https |
| `https://jenkins.<domain>` | Jenkins login behind WAF |
| WAF console | One Web ACL associated to **both** ALBs; managed rules + sampled requests |
| EC2 / ASG | Desired web instances healthy in the target group |
| MySQL EC2 | **No public IP**; reachable from web tier on 3306 only |
| Secrets Manager | DB secret present, **CMK-encrypted**; web role can read it |
| VPC → Flow logs | One to CloudWatch (CMK), one to private S3 (CMK, versioned) |
| `terraform validate` / `tfsec` | Success / 0 findings |

---

## 10. Security model

- **Edge:** WAFv2 with AWS free managed rule groups + custom IP blacklist on both ALBs.
- **Transport:** HTTPS only; **TLS 1.3-only** policy; HTTP 80 → 301 to 443.
- **Segmentation:** 3 tiers; web/DB/CI in private subnets; egress via NAT only.
- **Least-privilege SGs:** discrete rules, each described; no `0.0.0.0/0` except the public edge and the VPN data port; no internet SSH.
- **Secrets:** DB credentials in Secrets Manager (CMK); web tier reads at runtime via a scoped instance role — never in user-data/AMIs.
- **Encryption at rest:** rotating KMS CMKs for secrets, CloudWatch logs, flow-log S3, and VPN profiles S3; encrypted EBS; IMDSv2 required.
- **Identity:** OpenVPN logins federated to Azure AD (O365) via Cognito; central grant/revoke/disable.
- **Admin:** SSM Session Manager (no SSH keys/ports required).
- **Observability/SOC:** VPC Flow Logs to CloudWatch + private S3; CloudTrail data events recommended for bucket access audit.
- **Static analysis:** `tfsec` clean; design exceptions are documented with inline `#tfsec:ignore` justifications.

**Recommended next steps (not yet included):** remote state (S3 + DynamoDB lock), GuardDuty/Security Hub, AWS Config rules, CloudTrail org trail, WAF logging to the SOC bucket, per-environment `prod/` root.

---

## 11. Day-2 operations

- **Scale the web tier:** change `asg_min/desired/max_size` → `terraform apply`. ASG uses rolling instance refresh.
- **Rotate DB password:** update `TF_VAR_db_password` → apply (updates the secret + DB user). Web instances pick it up on next boot/refresh.
- **Add/disable a VPN user:** do it in Azure AD — no Terraform change needed.
- **Block an IP:** add to `waf_blacklist_ips` → apply.
- **Update AMIs / rotate instances:** change AMI vars → apply (launch template version bumps; ASG refreshes).

---

## 12. Teardown

```bash
cd environments/dev
terraform destroy
```
Notes: KMS keys have a 7-day deletion window; S3 buckets use `force_destroy = true` so they
empty on destroy. Route53 records and ACM certs created here are removed.

---

## 13. Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| `init` 502 from registry.terraform.io | Transient registry outage — retry, or use a provider mirror. |
| ACM validation hangs | `domain_name` zone not in Route53 or NS not delegated. Verify the public hosted zone. |
| 443 listener error on first apply | Cert still validating — apply is gated on `aws_acm_certificate_validation`; re-run apply. |
| Web page can't reach DB | Check `db_private_ip`, the web→db SG rule (3306), and that the secret host matches. |
| OpenVPN login fails | Azure AD redirect URI mismatch, or `azure_*` values wrong; check the Cognito IdP + app client. |
| Jenkins slave won't attach | Register the node in the UI and confirm SG 50000 (master) / egress (slave). |
| `tfsec` flags a new resource | Fix it, or add a justified single-line `#tfsec:ignore:<id>` directly above the block. |
```
