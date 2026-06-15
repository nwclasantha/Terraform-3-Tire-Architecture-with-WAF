# Jenkins-specific security groups (self-contained within the module).

# Public ALB for the Jenkins master.
resource "aws_security_group" "alb" {
  name        = "${var.name}-jenkins-alb-sg"
  description = "Jenkins ALB: public 80/443 in; 8080 to master"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-jenkins-alb-sg" })
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
  description       = "Public HTTP (redirected to HTTPS)"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_master" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Forward to Jenkins master 8080"
  referenced_security_group_id = aws_security_group.master.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
}

# Jenkins master.
resource "aws_security_group" "master" {
  name        = "${var.name}-jenkins-master-sg"
  description = "Jenkins master: 8080 from ALB, 50000 from slaves, SSH from bastion"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-jenkins-master-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "master_http_from_alb" {
  security_group_id            = aws_security_group.master.id
  description                  = "Web UI from ALB only"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "master_jnlp_from_slave" {
  security_group_id            = aws_security_group.master.id
  description                  = "JNLP agent port from slaves"
  referenced_security_group_id = aws_security_group.slave.id
  from_port                    = 50000
  to_port                      = 50000
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_ingress_rule" "master_ssh_from_bastion" {
  security_group_id            = aws_security_group.master.id
  description                  = "SSH from OpenVPN bastion only"
  referenced_security_group_id = var.bastion_sg_id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "master_all_out" {
  security_group_id = aws_security_group.master.id
  description       = "Egress for plugins/updates via NAT"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

# Jenkins slaves/agents.
resource "aws_security_group" "slave" {
  name        = "${var.name}-jenkins-slave-sg"
  description = "Jenkins slaves: SSH from bastion; egress to master + internet"
  vpc_id      = var.vpc_id
  tags        = merge(var.tags, { Name = "${var.name}-jenkins-slave-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "slave_ssh_from_bastion" {
  security_group_id            = aws_security_group.slave.id
  description                  = "SSH from OpenVPN bastion only"
  referenced_security_group_id = var.bastion_sg_id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "slave_all_out" {
  security_group_id = aws_security_group.slave.id
  description       = "Egress to master (8080/50000) and internet via NAT"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
