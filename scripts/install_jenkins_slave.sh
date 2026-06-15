#!/bin/bash
# Jenkins build agent (slave) bootstrap (Amazon Linux 2).
# Has Java + Docker + git + build tooling and reaches the master on 8080/50000.
# Releases to web/DB tiers run from here (the agents sit in the private app subnets).
# ${jenkins_master_host} injected by Terraform.
set -euxo pipefail

yum update -y
amazon-linux-extras enable corretto17
yum install -y java-17-amazon-corretto git docker
amazon-linux-extras install -y docker || true

systemctl enable docker
systemctl start docker

# Build tools for typical release pipelines.
yum install -y maven unzip rsync openssh-clients
usermod -aG docker ec2-user || true

# Record the master endpoint for the agent connection (JNLP). The actual agent
# secret is supplied when you register the node in the Jenkins UI.
cat > /etc/profile.d/jenkins_agent.sh <<EOF
export JENKINS_MASTER_URL="http://${jenkins_master_host}:8080"
EOF

# Install the Jenkins inbound agent jar for JNLP connections.
mkdir -p /opt/jenkins-agent
curl -fsSL -o /opt/jenkins-agent/agent.jar "http://${jenkins_master_host}:8080/jnlpJars/agent.jar" || \
  echo "WARN: master not ready yet; fetch agent.jar after master is up"
