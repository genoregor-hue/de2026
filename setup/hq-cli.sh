#!/bin/bash
# HQ-CLI Setup - ALT Linux | DHCP VLAN 200 | Session: 3b9ac6ea
# Generated: 2026-06-02 17:35:20
set -e
TZ_REGION="${TZ_REGION:-Europe/Moscow}"   # часовой пояс (Йошкар-Ола). Замени при необходимости.
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
[[ $EUID -ne 0 ]] && { log_error "Run as root!"; exit 1; }
echo "=============================================="
echo "        HQ-CLI Client Configuration"
echo "=============================================="
hostnamectl set-hostname hq-cli.au-team.irpo
# VLAN ID 200 назначается в Proxmox (VM → Hardware → Network → VLAN Tag=200)
mkdir -p /etc/net/ifaces/ens19
cat > /etc/net/ifaces/ens19/options << 'EOF'
TYPE=eth
BOOTPROTO=dhcp
CONFIG_IPV4=yes
DISABLED=no
NM_CONTROLLED=no
SYSTEMD_CONTROLLED=no
EOF
cat > /etc/resolv.conf.head << EOF
search au-team.irpo
nameserver 192.168.100.2
EOF
systemctl restart network && sleep 3
cat > /etc/resolv.conf << EOF
search au-team.irpo
nameserver 192.168.100.2
EOF
apt-get update || log_warn "apt-get update failed"
apt-get install -y vim tzdata || log_warn "Some packages failed"
timedatectl set-timezone ${TZ_REGION:-Europe/Moscow}
echo "=== Verification ==="
ip -4 addr show ens19 2>/dev/null | grep -q "inet " && log_info "DHCP lease: OK (VLAN 200 в Proxmox)" || log_error "DHCP: FAILED"
ip route | grep default && log_info "Gateway: OK" || log_warn "Gateway: check DHCP"
ping -c 1 ya.ru > /dev/null 2>&1 && log_info "Internet: OK" || log_warn "Internet: check"
echo "=== HQ-CLI Complete! ==="
