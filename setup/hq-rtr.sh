#!/bin/bash
# =============================================================================
# HQ-RTR Setup Script - ALT Linux (etcnet)
# DEMO-2026 Network Automation | Session: 3b9ac6ea
# Generated: 2026-06-02 17:35:00
# =============================================================================
set -e
TZ_REGION="${TZ_REGION:-Europe/Moscow}"   # часовой пояс (Йошкар-Ола). Замени при необходимости.
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
[[ $EUID -ne 0 ]] && { log_error "Run as root!"; exit 1; }
echo "=============================================="
echo "       HQ-RTR Router Configuration"
echo "=============================================="
log_step "Setting hostname..."
hostnamectl set-hostname hq-rtr.au-team.irpo
log_step "Configuring WAN interface ens19..."
mkdir -p /etc/net/ifaces/ens19
cat > /etc/net/ifaces/ens19/options << 'EOF'
TYPE=eth
BOOTPROTO=static
DISABLED=no
NM_CONTROLLED=no
SYSTEMD_CONTROLLED=no
CONFIG_IPV4=yes
EOF
echo "172.16.1.2/28" > /etc/net/ifaces/ens19/ipv4address
echo "default via 172.16.1.1" > /etc/net/ifaces/ens19/ipv4route
mkdir -p /etc/net/ifaces/ens20
cat > /etc/net/ifaces/ens20/options << 'EOF'
TYPE=eth
BOOTPROTO=static
DISABLED=no
NM_CONTROLLED=no
SYSTEMD_CONTROLLED=no
EOF
log_step "Configuring VLAN 100..."
mkdir -p /etc/net/ifaces/ens20.100
cat > /etc/net/ifaces/ens20.100/options << EOF
TYPE=vlan
HOST=ens20
VID=100
DISABLED=no
BOOTPROTO=static
ONBOOT=yes
CONFIG_IPV4=yes
EOF
echo "192.168.100.1/27" > /etc/net/ifaces/ens20.100/ipv4address
log_step "Configuring VLAN 200..."
mkdir -p /etc/net/ifaces/ens20.200
cat > /etc/net/ifaces/ens20.200/options << EOF
TYPE=vlan
HOST=ens20
VID=200
DISABLED=no
BOOTPROTO=static
ONBOOT=yes
CONFIG_IPV4=yes
EOF
echo "192.168.200.1/28" > /etc/net/ifaces/ens20.200/ipv4address
log_step "Configuring VLAN 999..."
mkdir -p /etc/net/ifaces/ens20.999
cat > /etc/net/ifaces/ens20.999/options << EOF
TYPE=vlan
HOST=ens20
VID=999
DISABLED=no
BOOTPROTO=static
ONBOOT=yes
CONFIG_IPV4=yes
EOF
echo "192.168.99.1/29" > /etc/net/ifaces/ens20.999/ipv4address
grep -q "^net.ipv4.ip_forward" /etc/net/sysctl.conf && \
    sed -i 's/^net.ipv4.ip_forward.*/net.ipv4.ip_forward = 1/' /etc/net/sysctl.conf || \
    echo "net.ipv4.ip_forward = 1" >> /etc/net/sysctl.conf
sysctl -w net.ipv4.ip_forward=1 > /dev/null
systemctl restart network && sleep 2
cat > /etc/resolv.conf.head << 'EOF'
nameserver 77.88.8.8
nameserver 8.8.8.8
EOF
cat > /etc/resolv.conf << 'EOF'
nameserver 77.88.8.8
nameserver 8.8.8.8
EOF
ping -c 2 -W 3 77.88.8.8 > /dev/null 2>&1 && log_info "Internet: OK" || { log_error "No internet!"; exit 1; }
apt-get update
apt-get install -y iptables frr dhcp-server vim tzdata sudo
timedatectl set-timezone ${TZ_REGION:-Europe/Moscow}
useradd -m net_admin 2>/dev/null || log_warn "User net_admin may already exist"
echo 'net_admin:P@ssw0rd' | chpasswd
usermod -a -G wheel net_admin
sed -i 's/^#WHEEL_USERS ALL=(ALL:ALL) NOPASSWD: ALL/WHEEL_USERS ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^# WHEEL_USERS ALL=(ALL:ALL) NOPASSWD: ALL/WHEEL_USERS ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
iptables -t nat -F POSTROUTING 2>/dev/null || true
iptables -t nat -A POSTROUTING -o ens19 -s 192.168.100.0/27 -j MASQUERADE
iptables -t nat -A POSTROUTING -o ens19 -s 192.168.200.0/28 -j MASQUERADE
mkdir -p /etc/sysconfig
iptables-save > /etc/sysconfig/iptables
systemctl enable --now iptables 2>/dev/null || true
mkdir -p /etc/net/ifaces/gre1
cat > /etc/net/ifaces/gre1/options << EOF
TYPE=iptun
TUNTYPE=gre
TUNLOCAL=172.16.1.2
TUNREMOTE=172.16.2.2
TUNOPTIONS='ttl 64'
HOST=ens19
BOOTPROTO=static
DISABLED=no
CONFIG_IPV4=yes
EOF
echo "10.10.10.1/30" > /etc/net/ifaces/gre1/ipv4address
sed -i 's/^ospfd=no/ospfd=yes/' /etc/frr/daemons
sed -i 's/^#ospfd=no/ospfd=yes/' /etc/frr/daemons
systemctl enable frr && systemctl restart frr && sleep 2
vtysh << 'VTYSH_EOF'
configure terminal
router ospf
  passive-interface default
  network 10.10.10.0/30 area 0
  network 192.168.100.0/27 area 0
  network 192.168.200.0/28 area 0
  area 0 authentication
exit
interface gre1
  no ip ospf passive
  ip ospf authentication-key 1245
exit
do write
end
VTYSH_EOF
cat > /etc/dhcp/dhcpd.conf << EOF
ddns-update-style none;
subnet 192.168.200.0 netmask 255.255.255.240
{
    option routers                  192.168.200.1;
    option subnet-mask              255.255.255.240;
    option domain-name-servers      192.168.100.2;
    option domain-name              "au-team.irpo";
    range dynamic-bootp             192.168.200.2 192.168.200.14;
    default-lease-time              21600;
    max-lease-time                  43200;
}
EOF
echo "DHCPDARGS=ens20.200" > /etc/sysconfig/dhcpd
systemctl enable dhcpd
systemctl restart network && sleep 3
systemctl restart frr && sleep 2
cat > /etc/resolv.conf.head << EOF
search au-team.irpo
nameserver 192.168.100.2
EOF
cat > /etc/resolv.conf << EOF
search au-team.irpo
nameserver 192.168.100.2
EOF
systemctl restart dhcpd || log_warn "DHCP may need VLAN interface"
echo "=== Verification ==="
hostnamectl
id net_admin && log_info "net_admin: OK" || log_error "net_admin: FAILED"
ip -4 addr show ens19 2>/dev/null | grep -q "172.16.1.2" && log_info "WAN: OK" || log_error "WAN: FAILED"
ip -4 addr show ens20.100 2>/dev/null | grep -q "192.168.100.1" && log_info "VLAN 100: OK" || log_error "VLAN 100: FAILED"
ip -4 addr show ens20.200 2>/dev/null | grep -q "192.168.200.1" && log_info "VLAN 200: OK" || log_error "VLAN 200: FAILED"
ip -4 addr show ens20.999 2>/dev/null | grep -q "192.168.99.1" && log_info "VLAN 999: OK" || log_error "VLAN 999: FAILED"
ip -4 addr show gre1 2>/dev/null | grep -q "10.10.10.1" && log_info "GRE: OK" || log_warn "GRE: waiting"
systemctl is-active frr > /dev/null && log_info "FRR: OK" || log_error "FRR: FAILED"
systemctl is-active dhcpd > /dev/null && log_info "DHCP: OK" || log_warn "DHCP: check"
echo "=== HQ-RTR Complete! ==="
