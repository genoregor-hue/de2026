#!/bin/bash
# =============================================================================
# ISP Router Setup Script - ALT Linux (etcnet)
# DEMO-2026 Network Automation | Session: 3b9ac6ea
# Generated: 2026-06-02 17:34:36
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
echo "        ISP Router Configuration"
echo "=============================================="
log_step "Setting hostname to isp.au-team.irpo..."
hostnamectl set-hostname isp.au-team.irpo
log_info "WAN: ens19 (DHCP)"
log_info "HQ:  ens20 (172.16.1.1/28)"
log_info "BR:  ens21 (172.16.2.1/28)"
mkdir -p /etc/net/ifaces/ens19
cat > /etc/net/ifaces/ens19/options << 'EOF'
TYPE=eth
BOOTPROTO=dhcp
CONFIG_WIRELESS=no
SYSTEMD_BOOTPROTO=dhcp4
CONFIG_IPV4=yes
DISABLED=no
NM_CONTROLLED=no
SYSTEMD_CONTROLLED=no
EOF
mkdir -p /etc/net/ifaces/ens20
cat > /etc/net/ifaces/ens20/options << 'EOF'
TYPE=eth
BOOTPROTO=static
DISABLED=no
NM_CONTROLLED=no
SYSTEMD_CONTROLLED=no
CONFIG_IPV4=yes
EOF
echo "172.16.1.1/28" > /etc/net/ifaces/ens20/ipv4address
mkdir -p /etc/net/ifaces/ens21
cat > /etc/net/ifaces/ens21/options << 'EOF'
TYPE=eth
BOOTPROTO=static
DISABLED=no
NM_CONTROLLED=no
SYSTEMD_CONTROLLED=no
CONFIG_IPV4=yes
EOF
echo "172.16.2.1/28" > /etc/net/ifaces/ens21/ipv4address
grep -q "^net.ipv4.ip_forward" /etc/net/sysctl.conf && \
    sed -i 's/^net.ipv4.ip_forward.*/net.ipv4.ip_forward = 1/' /etc/net/sysctl.conf || \
    echo "net.ipv4.ip_forward = 1" >> /etc/net/sysctl.conf
sysctl -w net.ipv4.ip_forward=1 > /dev/null
apt-get update && apt-get install -y iptables || log_warn "iptables may already be installed"
iptables -t nat -F POSTROUTING 2>/dev/null || true
iptables -t nat -A POSTROUTING -s 172.16.1.0/28 -o ens19 -j MASQUERADE
iptables -t nat -A POSTROUTING -s 172.16.2.0/28 -o ens19 -j MASQUERADE
mkdir -p /etc/sysconfig
iptables-save > /etc/sysconfig/iptables
systemctl enable --now iptables 2>/dev/null || true
apt-get install -y tzdata 2>/dev/null || true
timedatectl set-timezone ${TZ_REGION:-Europe/Moscow}
systemctl restart network
sleep 3
echo "=== Verification ==="
ip -4 addr show ens19 2>/dev/null | grep -oP 'inet \K[\d./]+' && log_info "ens19: OK" || log_warn "ens19: waiting for DHCP"
ip -4 addr show ens20 2>/dev/null | grep -q "172.16.1.1" && log_info "ens20: OK" || log_error "ens20: FAILED"
ip -4 addr show ens21 2>/dev/null | grep -q "172.16.2.1" && log_info "ens21: OK" || log_error "ens21: FAILED"
[[ $(sysctl -n net.ipv4.ip_forward) == "1" ]] && log_info "IP Forward: OK" || log_error "IP Forward: FAILED"
iptables -t nat -L POSTROUTING -n | grep -q MASQUERADE && log_info "NAT: OK" || log_warn "NAT: check"
iptables -t nat -L POSTROUTING -n -v --line-numbers
ping -c 2 -W 2 77.88.8.8 > /dev/null 2>&1 && log_info "Internet: OK" || log_warn "Internet: No connection"
echo "=== ISP Configuration Complete ==="
