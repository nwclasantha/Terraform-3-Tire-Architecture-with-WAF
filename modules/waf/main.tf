resource "aws_wafv2_ip_set" "blacklist" {
  name               = "${var.name}-blacklist"
  description        = "Blocked source IPs"
  scope              = "REGIONAL"
  ip_address_version = "IPV4"
  addresses          = var.blacklist_ips
  tags               = var.tags
}

resource "aws_wafv2_web_acl" "this" {
  name        = "${var.name}-web-acl"
  description = "Regional Web ACL for the ALB with AWS free managed rule groups"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  # ---- AWS free managed rule groups ----
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "KnownBadInputs"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesLinuxRuleSet"
    priority = 3
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesLinuxRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "LinuxRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesAmazonIpReputationList"
    priority = 4
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AmazonIpReputation"
      sampled_requests_enabled   = true
    }
  }

  # ---- Custom IP blacklist (only when addresses are provided) ----
  dynamic "rule" {
    for_each = length(var.blacklist_ips) > 0 ? [1] : []
    content {
      name     = "IPBlacklist"
      priority = 10
      action {
        block {}
      }
      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.blacklist.arn
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "IPBlacklist"
        sampled_requests_enabled   = true
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name}-web-acl"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}

# The critical piece that was missing in the original stack: bind the ACL to the ALB(s).
# Use count (not for_each): the ALB ARNs are computed/unknown at plan time, and Terraform
# cannot use unknown values as for_each keys. The list length IS known at plan, so count works.
resource "aws_wafv2_web_acl_association" "this" {
  count        = length(var.resource_arns)
  resource_arn = var.resource_arns[count.index]
  web_acl_arn  = aws_wafv2_web_acl.this.arn
}
