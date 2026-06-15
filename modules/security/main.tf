# Hardened, least-privilege security groups.
# Each rule is a discrete aws_vpc_security_group_*_rule with an explicit description.
# No SSH from the internet anywhere — administration is via SSM Session Manager.

# ============================ ALB SG (public edge) ============================
resource "aws_security_group" "alb" {
  name        = "${var.name}-alb-sg"
  description = "ALB edge: public 80/443 in, only 80 to web tier out"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-alb-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "alb_https" {
  security_group_id = aws_security_group.alb.id
  description       = "Public HTTPS"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "Public HTTP (redirected to HTTPS by the listener)"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_web" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward to web tier on HTTP only"
  referenced_security_group_id = aws_security_group.web.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

# ============================ Web tier SG (private) ============================
resource "aws_security_group" "web" {
  name        = "${var.name}-web-sg"
  description = "Web tier: 80 from ALB only; egress to internet (NAT) and DB 3306"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-web-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "web_from_alb" {
  security_group_id            = aws_security_group.web.id
  description                  = "HTTP from ALB only"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "web_https_out" {
  security_group_id = aws_security_group.web.id
  description       = "HTTPS out for package updates / SSM via NAT"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "web_http_out" {
  security_group_id = aws_security_group.web.id
  description       = "HTTP out for package repos via NAT"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "web_to_db" {
  security_group_id            = aws_security_group.web.id
  description                  = "MySQL to database tier only"
  referenced_security_group_id = aws_security_group.db.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}

# ============================ DB tier SG (private) ============================
resource "aws_security_group" "db" {
  name        = "${var.name}-db-sg"
  description = "Database tier: 3306 from web tier only; egress for updates only"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-db-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "db_from_web" {
  security_group_id            = aws_security_group.db.id
  description                  = "MySQL from web tier only"
  referenced_security_group_id = aws_security_group.web.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "db_https_out" {
  security_group_id = aws_security_group.db.id
  description       = "HTTPS out for package updates / SSM via NAT"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "db_http_out" {
  security_group_id = aws_security_group.db.id
  description       = "HTTP out for package repos via NAT"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

# ===================== Bastion SG (OpenVPN secure access) =====================
# Public-facing OpenVPN server. Admins connect over the VPN tunnel and then reach
# private web/DB instances on SSH/MySQL. The OpenVPN management/UI and SSH are
# restricted to var.admin_cidr; the VPN data port is open to the internet.
resource "aws_security_group" "bastion" {
  name        = "${var.name}-bastion-sg"
  description = "OpenVPN bastion: VPN in from internet, admin UI/SSH from trusted CIDR"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-bastion-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "bastion_openvpn_udp" {
  security_group_id = aws_security_group.bastion.id
  description       = "OpenVPN UDP tunnel"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 1194
  to_port           = 1194
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_ingress_rule" "bastion_openvpn_tcp" {
  security_group_id = aws_security_group.bastion.id
  description       = "OpenVPN TCP fallback / client web portal"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "bastion_admin_ui" {
  security_group_id = aws_security_group.bastion.id
  description       = "OpenVPN Access Server admin UI from trusted CIDR"
  cidr_ipv4         = var.admin_cidr
  from_port         = 943
  to_port           = 943
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "bastion_ssh" {
  security_group_id = aws_security_group.bastion.id
  description       = "SSH to bastion from trusted CIDR only"
  cidr_ipv4         = var.admin_cidr
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "bastion_all_out" {
  security_group_id = aws_security_group.bastion.id
  description       = "Allow bastion egress (reach private tiers + internet)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# ----- Admin access from the bastion into the private tiers -----
resource "aws_vpc_security_group_ingress_rule" "web_ssh_from_bastion" {
  security_group_id            = aws_security_group.web.id
  description                  = "SSH from OpenVPN bastion only"
  referenced_security_group_id = aws_security_group.bastion.id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "db_ssh_from_bastion" {
  security_group_id            = aws_security_group.db.id
  description                  = "SSH from OpenVPN bastion only"
  referenced_security_group_id = aws_security_group.bastion.id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "db_mysql_from_bastion" {
  security_group_id            = aws_security_group.db.id
  description                  = "MySQL admin from OpenVPN bastion only"
  referenced_security_group_id = aws_security_group.bastion.id
  from_port                    = 3306
  to_port                      = 3306
  ip_protocol                  = "tcp"
}
