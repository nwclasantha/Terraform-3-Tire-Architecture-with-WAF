#!/bin/bash
# Web tier bootstrap (Amazon Linux 2). Installs Apache + PHP.
# The DB connection (host/name/user/password) is pulled at runtime from AWS Secrets
# Manager using the instance's IAM role — NO credentials are baked into user-data.
# Rendered via templatefile(): ${aws_region}, ${db_secret_name} injected by Terraform.
set -euxo pipefail

yum update -y
yum install -y httpd php php-mysqlnd mariadb jq awscli

systemctl enable httpd

# ---- Securely retrieve the DB connection secret via the instance role ----
SECRET_JSON=$(aws secretsmanager get-secret-value \
  --secret-id "${db_secret_name}" \
  --region "${aws_region}" \
  --query SecretString --output text)

DB_HOST=$(echo "$SECRET_JSON" | jq -r .host)
DB_NAME=$(echo "$SECRET_JSON" | jq -r .dbname)
DB_USER=$(echo "$SECRET_JSON" | jq -r .username)
DB_PASS=$(echo "$SECRET_JSON" | jq -r .password)

# Persist non-secret connection info for the app; the password stays out of disk where
# possible (PHP reads it from Secrets Manager via the SDK in real apps). For this demo we
# write a root-only env file.
umask 077
cat > /etc/httpd/conf.d/app_db.conf <<EOF
SetEnv DB_HOST $DB_HOST
SetEnv DB_NAME $DB_NAME
SetEnv DB_USER $DB_USER
EOF

cat > /etc/sysconfig/app_db_secret <<EOF
DB_PASSWORD=$DB_PASS
EOF
chmod 600 /etc/sysconfig/app_db_secret

# Landing page confirms wiring without printing the password.
cat > /var/www/html/index.php <<'PHP'
<?php
echo "<h1>3-Tier WAF Demo - Web Tier</h1>";
echo "<p>Served by: " . gethostname() . "</p>";
echo "<p>DB host: " . htmlspecialchars(getenv('DB_HOST')) . "</p>";
echo "<p>DB name: " . htmlspecialchars(getenv('DB_NAME')) . "</p>";
echo "<p>Secret retrieved from AWS Secrets Manager via instance role.</p>";
PHP

systemctl restart httpd

# Clear the secret material from the shell environment.
unset SECRET_JSON DB_PASS
