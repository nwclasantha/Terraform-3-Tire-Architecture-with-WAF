locals {
  fqdn = "${var.subdomain}.${var.domain_name}"
}

data "aws_route53_zone" "this" {
  name         = var.domain_name
  private_zone = false
}

# ============================ Jenkins ALB (public, WAF-protected) ============================
# Intentionally internet-facing, protected by the WAFv2 Web ACL + Jenkins auth.
#tfsec:ignore:aws-elb-alb-not-public
resource "aws_lb" "jenkins" {
  name                       = "${var.name}-jenkins-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = var.public_subnet_ids
  drop_invalid_header_fields = true
  tags                       = merge(var.tags, { Name = "${var.name}-jenkins-alb" })
}

resource "aws_lb_target_group" "jenkins" {
  name     = "${var.name}-jenkins-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled  = true
    path     = "/login"
    protocol = "HTTP"
    matcher  = "200-399"
  }

  tags = merge(var.tags, { Name = "${var.name}-jenkins-tg" })
}

# ----- ACM cert (DNS validation) -----
resource "aws_acm_certificate" "jenkins" {
  domain_name       = local.fqdn
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
  tags = merge(var.tags, { Name = "${var.name}-jenkins-cert" })
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.jenkins.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  zone_id         = data.aws_route53_zone.this.zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "jenkins" {
  certificate_arn         = aws_acm_certificate.jenkins.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# ----- Listeners: 80 -> 443 redirect, 443 -> forward -----
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.jenkins.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.jenkins.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.ssl_policy
  certificate_arn   = aws_acm_certificate_validation.jenkins.certificate_arn
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.jenkins.arn
  }
}

resource "aws_route53_record" "jenkins" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = local.fqdn
  type    = "A"
  alias {
    name                   = aws_lb.jenkins.dns_name
    zone_id                = aws_lb.jenkins.zone_id
    evaluate_target_health = true
  }
}

# ============================ Jenkins master ============================
resource "aws_instance" "master" {
  ami                    = var.ami_id
  instance_type          = var.master_instance_type
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [aws_security_group.master.id]
  iam_instance_profile   = var.instance_profile_name
  key_name               = var.key_name != "" ? var.key_name : null

  user_data = file("${path.module}/../../scripts/install_jenkins_master.sh")

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }
  root_block_device {
    encrypted   = true
    volume_size = 30
    volume_type = "gp3"
  }

  tags = merge(var.tags, { Name = "${var.name}-jenkins-master", Tier = "ci" })
}

resource "aws_lb_target_group_attachment" "master" {
  target_group_arn = aws_lb_target_group.jenkins.arn
  target_id        = aws_instance.master.id
  port             = 8080
}

# ============================ Jenkins slaves/agents ============================
resource "aws_instance" "slave" {
  count                  = var.slave_count
  ami                    = var.ami_id
  instance_type          = var.slave_instance_type
  subnet_id              = var.private_subnet_ids[count.index % length(var.private_subnet_ids)]
  vpc_security_group_ids = [aws_security_group.slave.id]
  iam_instance_profile   = var.instance_profile_name
  key_name               = var.key_name != "" ? var.key_name : null

  user_data = templatefile("${path.module}/../../scripts/install_jenkins_slave.sh", {
    jenkins_master_host = aws_instance.master.private_ip
  })

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }
  root_block_device {
    encrypted   = true
    volume_size = 30
    volume_type = "gp3"
  }

  tags = merge(var.tags, { Name = "${var.name}-jenkins-slave-${count.index + 1}", Tier = "ci" })
}
