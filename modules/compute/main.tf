resource "aws_launch_template" "web" {
  name_prefix   = "${var.name}-web-"
  image_id      = var.ami_id
  instance_type = var.instance_type
  key_name      = var.key_name != "" ? var.key_name : null

  iam_instance_profile {
    name = var.instance_profile_name
  }

  vpc_security_group_ids = [var.web_sg_id]

  user_data = base64encode(templatefile("${path.module}/../../scripts/install_apache.sh", {
    aws_region     = var.aws_region
    db_secret_name = var.db_secret_name
  }))

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 10
      volume_type = "gp3"
      encrypted   = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.name}-web", Tier = "web" })
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "web" {
  name                      = "${var.name}-web-asg"
  vpc_zone_identifier       = var.subnet_ids
  min_size                  = var.min_size
  desired_capacity          = var.desired_capacity
  max_size                  = var.max_size
  target_group_arns         = [var.target_group_arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-web"
    propagate_at_launch = true
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Target-tracking autoscaling on average CPU.
resource "aws_autoscaling_policy" "cpu" {
  name                   = "${var.name}-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 60.0
  }
}
