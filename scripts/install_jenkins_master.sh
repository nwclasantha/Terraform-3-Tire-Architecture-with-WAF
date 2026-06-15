#!/bin/bash
# Jenkins master bootstrap (Amazon Linux 2). Runs behind an internal-to-public ALB + WAF.
# Listens on 8080 (the ALB terminates TLS and forwards here). Agents connect on 50000.
set -euxo pipefail

yum update -y
amazon-linux-extras enable corretto17
yum install -y java-17-amazon-corretto git

wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
yum install -y jenkins

# Fix the inbound agent (JNLP) port so slaves can attach deterministically.
mkdir -p /var/lib/jenkins/init.groovy.d
cat > /var/lib/jenkins/init.groovy.d/agent-port.groovy <<'GROOVY'
import jenkins.model.Jenkins
Jenkins.instance.setSlaveAgentPort(50000)
Jenkins.instance.save()
GROOVY
chown -R jenkins:jenkins /var/lib/jenkins

systemctl enable jenkins
systemctl start jenkins

# Initial admin password is at /var/lib/jenkins/secrets/initialAdminPassword
# Retrieve it via SSM Session Manager during first-time setup.
