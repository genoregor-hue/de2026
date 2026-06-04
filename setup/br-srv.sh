#!/bin/bash
# BR-SRV Setup - ALT Linux | SSH | Session: 3b9ac6ea
# Generated: 2026-06-02 17:35:17
set +e
export PATH=$PATH:/sbin:/usr/sbin
TZ_REGION="${TZ_REGION:-Europe/Moscow}"   # часовой пояс (Йошкар-Ола). Замени при необходимости.
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
[[ $EUID -ne 0 ]] && { log_error "Run as root!"; exit 1; }
echo "=============================================="
echo "        BR-SRV Server Configuration"
echo "=============================================="
hostnamectl set-hostname br-srv.au-team.irpo
mkdir -p /etc/net/ifaces/ens19
cat > /etc/net/ifaces/ens19/options << 'EOF'
TYPE=eth
BOOTPROTO=static
DISABLED=no
NM_CONTROLLED=no
SYSTEMD_CONTROLLED=no
CONFIG_IPV4=yes
EOF
echo "192.168.0.2/28" > /etc/net/ifaces/ens19/ipv4address
echo "default via 192.168.0.1" > /etc/net/ifaces/ens19/ipv4route
cat > /etc/resolv.conf.head << EOF
search au-team.irpo
nameserver 192.168.100.2
EOF
systemctl restart network && sleep 2
cat > /etc/resolv.conf << EOF
search au-team.irpo
nameserver 192.168.100.2
EOF
apt-get update || log_warn "apt-get update failed"
apt-get install -y vim-console tzdata sudo || log_warn "Some packages failed"
ln -sf /usr/share/zoneinfo/${TZ_REGION:-Europe/Moscow} /etc/localtime 2>/dev/null || timedatectl set-timezone ${TZ_REGION:-Europe/Moscow} 2>/dev/null || true
useradd -m -u 2026 sshuser 2>/dev/null || log_warn "User may exist"
echo 'sshuser:P@ssw0rd' | chpasswd
usermod -a -G wheel sshuser
sed -i 's/^#WHEEL_USERS ALL=(ALL:ALL) NOPASSWD: ALL/WHEEL_USERS ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^# WHEEL_USERS ALL=(ALL:ALL) NOPASSWD: ALL/WHEEL_USERS ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^#Port 22/Port 2026/' /etc/openssh/sshd_config
sed -i 's/^Port 22/Port 2026/' /etc/openssh/sshd_config
grep -q "^AllowUsers" /etc/openssh/sshd_config || echo "AllowUsers sshuser" >> /etc/openssh/sshd_config
grep -q "^MaxAuthTries" /etc/openssh/sshd_config || echo "MaxAuthTries 2" >> /etc/openssh/sshd_config
grep -q "^Banner" /etc/openssh/sshd_config || echo "Banner /etc/openssh/banner" >> /etc/openssh/sshd_config
cat > /etc/openssh/banner << 'BANNER_EOF'
Authorized access only
BANNER_EOF
systemctl restart sshd
echo "=== Verification ==="
hostnamectl
ip -4 addr show ens19 2>/dev/null | grep -q "192.168.0.2" && log_info "ens19: OK" || log_error "ens19: FAILED"
id sshuser && log_info "User: OK" || log_error "User: FAILED"
systemctl is-active sshd > /dev/null && log_info "SSH: OK (port 2026)" || log_error "SSH: FAILED"
echo "=== BR-SRV Complete! ==="
