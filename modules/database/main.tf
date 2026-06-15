resource "aws_instance" "mysql" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.db_sg_id]
  iam_instance_profile   = var.instance_profile_name
  key_name               = var.key_name != "" ? var.key_name : null

  # Private tier — never assign a public IP.
  associate_public_ip_address = false

  user_data = templatefile("${path.module}/../../scripts/install_mysql.sh", {
    db_name     = var.db_name
    db_user     = var.db_username
    db_password = var.db_password
    app_cidr    = var.app_cidr
  })

  root_block_device {
    encrypted   = true
    volume_size = 20
    volume_type = "gp3"
  }

  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  tags = merge(var.tags, { Name = "${var.name}-mysql", Tier = "database" })
}
