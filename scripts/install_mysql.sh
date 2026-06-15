#!/bin/bash
# Database tier bootstrap (Amazon Linux 2). Installs MariaDB (MySQL-compatible) server.
# Rendered via templatefile(): ${db_name}, ${db_user}, ${db_password}, ${app_cidr} injected by Terraform.
set -euxo pipefail

yum update -y
yum install -y mariadb-server

systemctl enable mariadb
systemctl start mariadb

# Bind to all interfaces so the private web tier can reach it (SG still restricts to web_sg).
sed -i 's/^bind-address.*/bind-address=0.0.0.0/' /etc/my.cnf 2>/dev/null || true
systemctl restart mariadb

# Create application database + a user limited to the app subnet range.
mysql <<SQL
CREATE DATABASE IF NOT EXISTS ${db_name};
CREATE USER IF NOT EXISTS '${db_user}'@'${app_cidr}' IDENTIFIED BY '${db_password}';
GRANT ALL PRIVILEGES ON ${db_name}.* TO '${db_user}'@'${app_cidr}';
FLUSH PRIVILEGES;
SQL
