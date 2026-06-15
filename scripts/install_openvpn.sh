#!/bin/bash
# OpenVPN bastion bootstrap (Ubuntu 22.04) with OIDC SSO via AWS Cognito + Azure AD.
#
# Identity flow:
#   OpenVPN client --(OIDC Auth Code)--> openvpn-auth-oauth2 --> Cognito hosted UI
#       --> Azure AD (O365) login  ==> only valid Azure AD users can connect.
#   Grant / revoke / disable users centrally in Azure AD; no server changes needed.
#
# Over the established tunnel approved developers can SCP/SFTP files to the web and DB
# servers to manage urgent incidents. The tunnel routes into the VPC (${vpc_cidr}).
#
# Terraform-injected vars:
#   ${vpc_cidr} ${aws_region} ${oidc_issuer} ${oidc_client_id} ${oidc_client_secret}
#   ${profiles_bucket}
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y openvpn easy-rsa iptables-persistent awscli curl

echo "net.ipv4.ip_forward=1" > /etc/sysctl.d/99-openvpn.conf
sysctl --system

# ---------------- PKI (TLS transport; identity is via OIDC) ----------------
make-cadir /etc/openvpn/easy-rsa
cd /etc/openvpn/easy-rsa
./easyrsa init-pki
echo | ./easyrsa build-ca nopass
./easyrsa gen-dh
./easyrsa build-server-full server nopass
./easyrsa build-client-full client nopass
openvpn --genkey secret /etc/openvpn/ta.key
cp pki/ca.crt pki/dh.pem pki/issued/server.crt pki/private/server.key /etc/openvpn/

# ---------------- openvpn-auth-oauth2 (OIDC bridge) ----------------
OAUTH2_VER="1.20.0"
curl -fsSL -o /tmp/oauth2.deb \
  "https://github.com/jkroepke/openvpn-auth-oauth2/releases/download/v$${OAUTH2_VER}/openvpn-auth-oauth2_$${OAUTH2_VER}_linux_amd64.deb" \
  && dpkg -i /tmp/oauth2.deb || echo "WARN: pin/download openvpn-auth-oauth2 manually if release URL changed"

install -d -m 0750 /etc/openvpn-auth-oauth2
cat > /etc/openvpn-auth-oauth2/config.yaml <<EOF
debug: false
log:
  format: console
http:
  listen: ":9000"
  baseurl: "http://localhost:9000/"
  secret: "$(openssl rand -hex 16)"
openvpn:
  addr: "unix:///run/openvpn/server.sock"
  bypass:
    common-names: []
oauth2:
  issuer: "${oidc_issuer}"
  client:
    id: "${oidc_client_id}"
    secret: "${oidc_client_secret}"
  scopes:
    - openid
    - email
    - profile
  validate:
    groups: []
EOF
chmod 0640 /etc/openvpn-auth-oauth2/config.yaml
systemctl enable openvpn-auth-oauth2 || true
systemctl restart openvpn-auth-oauth2 || true

# ---------------- OpenVPN server config (management socket -> oauth2) ----------------
install -d -m 0755 /run/openvpn
cat > /etc/openvpn/server.conf <<EOF
port 1194
proto udp
dev tun
ca ca.crt
cert server.crt
key server.key
dh dh.pem
tls-auth ta.key 0
server 10.8.0.0 255.255.255.0
push "route ${vpc_cidr}"
keepalive 10 120
cipher AES-256-GCM
management /run/openvpn/server.sock unix
management-client-auth
management-hold
persist-key
persist-tun
user nobody
group nogroup
verb 3
EOF

PRIMARY_IF=$(ip route | awk '/default/ {print $5; exit}')
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o "$PRIMARY_IF" -j MASQUERADE
netfilter-persistent save

systemctl enable openvpn@server
systemctl restart openvpn@server
systemctl restart openvpn-auth-oauth2 || true

# ---------------- Shared client profile (SSO login at connect time) ----------------
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
cat > /tmp/client.ovpn <<OVPN
client
dev tun
proto udp
remote $PUBLIC_IP 1194
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth-user-pass
auth-retry interact
cipher AES-256-GCM
verb 3
key-direction 1
<ca>
$(cat /etc/openvpn/ca.crt)
</ca>
<cert>
$(cat /etc/openvpn/easy-rsa/pki/issued/client.crt)
</cert>
<key>
$(cat /etc/openvpn/easy-rsa/pki/private/client.key)
</key>
<tls-auth>
$(cat /etc/openvpn/ta.key)
</tls-auth>
OVPN

# Single SSO-enabled profile; the actual user identity is resolved at login via Azure AD.
aws s3 cp /tmp/client.ovpn "s3://${profiles_bucket}/profiles/client-sso.ovpn" --region "${aws_region}" --sse AES256
shred -u /tmp/client.ovpn
