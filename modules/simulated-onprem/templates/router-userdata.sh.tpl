#!/bin/bash
#------------------------------------------------------------------------------
# Simulated On-Premises Router Configuration
# strongSwan (IPsec) + FRR (BGP) on Amazon Linux 2023.
#
# Pre-shared keys are fetched at boot from SSM Parameter Store. They are not
# interpolated into this template by Terraform.
#------------------------------------------------------------------------------

set -euo pipefail
exec > >(tee /var/log/router-setup.log) 2>&1

echo "=== Starting router configuration ==="

TOKEN=$(curl -sS -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
LOCAL_IP=$(curl -sS -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)
REGION=$(curl -sS -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/region)

echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.d/99-router.conf
echo "net.ipv4.conf.all.accept_redirects = 0" >> /etc/sysctl.d/99-router.conf
echo "net.ipv4.conf.all.send_redirects = 0" >> /etc/sysctl.d/99-router.conf
sysctl -p /etc/sysctl.d/99-router.conf

echo "=== Installing strongSwan and FRR ==="
dnf install -y strongswan frr frr-selinux awscli

TUNNEL1_PSK=""
TUNNEL2_PSK=""
%{ if tunnel1_psk_parameter != "" }
TUNNEL1_PSK=$(aws ssm get-parameter --region "$REGION" --name "${tunnel1_psk_parameter}" --with-decryption --query 'Parameter.Value' --output text)
%{ endif }
%{ if tunnel2_psk_parameter != "" }
TUNNEL2_PSK=$(aws ssm get-parameter --region "$REGION" --name "${tunnel2_psk_parameter}" --with-decryption --query 'Parameter.Value' --output text)
%{ endif }

echo "=== Configuring strongSwan ==="

cat > /etc/strongswan/ipsec.conf << 'EOF'
config setup
    charondebug="ike 2, knl 2, cfg 2, net 2, esp 2, dmn 2, mgr 2"
    uniqueids=no

conn %default
    keyexchange=ikev2
    ike=aes256gcm16-prfsha256-ecp384!
    esp=aes256gcm16-ecp384!
    ikelifetime=8h
    lifetime=1h
    dpddelay=10s
    dpdtimeout=30s
    dpdaction=restart
    authby=secret
    auto=start

conn tunnel1
    left=%defaultroute
    leftid=${tunnel1_cgw_inside_ip}
    leftsubnet=0.0.0.0/0
    right=${tunnel1_aws_endpoint}
    rightsubnet=0.0.0.0/0
    mark=100
    leftupdown=/etc/strongswan/ipsec-vti.sh

conn tunnel2
    left=%defaultroute
    leftid=${tunnel2_cgw_inside_ip}
    leftsubnet=0.0.0.0/0
    right=${tunnel2_aws_endpoint}
    rightsubnet=0.0.0.0/0
    mark=200
    leftupdown=/etc/strongswan/ipsec-vti.sh
EOF

cat > /etc/strongswan/ipsec.secrets << EOF
${tunnel1_cgw_inside_ip} ${tunnel1_aws_endpoint} : PSK "$TUNNEL1_PSK"
${tunnel2_cgw_inside_ip} ${tunnel2_aws_endpoint} : PSK "$TUNNEL2_PSK"
EOF
chmod 600 /etc/strongswan/ipsec.secrets

cat > /etc/strongswan/ipsec-vti.sh << 'VTISCRIPT'
#!/bin/bash

VTI_IF="vti$${PLUTO_UNIQUEID}"
MARK="$${PLUTO_MARK_OUT%%/*}"

case "$${PLUTO_VERB}" in
    up-client)
        ip tunnel add $${VTI_IF} local $${PLUTO_ME} remote $${PLUTO_PEER} mode vti key $${MARK}
        sysctl -w net.ipv4.conf.$${VTI_IF}.disable_policy=1
        sysctl -w net.ipv4.conf.$${VTI_IF}.rp_filter=2
        ip link set $${VTI_IF} up mtu 1419
        ;;
    down-client)
        ip tunnel del $${VTI_IF}
        ;;
esac
VTISCRIPT
chmod +x /etc/strongswan/ipsec-vti.sh

echo "=== Creating VTI interfaces ==="
ip tunnel add vti1 local "$LOCAL_IP" remote ${tunnel1_aws_endpoint} mode vti key 100
ip addr add ${tunnel1_cgw_inside_ip}/30 dev vti1
sysctl -w net.ipv4.conf.vti1.disable_policy=1
sysctl -w net.ipv4.conf.vti1.rp_filter=2
ip link set vti1 up mtu 1419

ip tunnel add vti2 local "$LOCAL_IP" remote ${tunnel2_aws_endpoint} mode vti key 200
ip addr add ${tunnel2_cgw_inside_ip}/30 dev vti2
sysctl -w net.ipv4.conf.vti2.disable_policy=1
sysctl -w net.ipv4.conf.vti2.rp_filter=2
ip link set vti2 up mtu 1419

echo "=== Configuring FRR ==="
sed -i 's/bgpd=no/bgpd=yes/' /etc/frr/daemons

cat > /etc/frr/frr.conf << EOF
frr version 8.5
frr defaults traditional
hostname onprem-router
log syslog informational
service integrated-vtysh-config
!
router bgp ${customer_asn}
 bgp router-id ${private_interface_ip}
 no bgp ebgp-requires-policy
 !
 neighbor ${tunnel1_aws_inside_ip} remote-as ${aws_asn}
 neighbor ${tunnel1_aws_inside_ip} timers 10 30
 neighbor ${tunnel2_aws_inside_ip} remote-as ${aws_asn}
 neighbor ${tunnel2_aws_inside_ip} timers 10 30
 !
 address-family ipv4 unicast
  network ${onprem_cidr}
  network ${vpc_cidr}
  neighbor ${tunnel1_aws_inside_ip} soft-reconfiguration inbound
  neighbor ${tunnel2_aws_inside_ip} soft-reconfiguration inbound
 exit-address-family
!
ip route ${onprem_cidr} Null0
!
line vty
!
EOF

chmod 640 /etc/frr/frr.conf
chown frr:frr /etc/frr/frr.conf

echo "=== Starting services ==="
systemctl enable strongswan
systemctl start strongswan
systemctl enable frr
systemctl start frr

echo "=== Router configuration complete ==="
echo "Check IPsec status: strongswan status"
echo "Check BGP status: vtysh -c 'show bgp summary'"
echo "Check routes: vtysh -c 'show ip route'"
