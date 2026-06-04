#!/bin/bash
# =============================================================================
# HQ-SRV Setup Script - ALT Linux | DNS + SSH + Users
# DEMO-2026 | Session: 3b9ac6ea
# Generated: 2026-06-02 17:35:11
# =============================================================================
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
echo "        HQ-SRV Server Configuration"
echo "=============================================="
log_step "Setting hostname..."
hostnamectl set-hostname hq-srv.au-team.irpo
# VLAN ID 100 назначается в Proxmox (VM → Hardware → Network → VLAN Tag=100)
mkdir -p /etc/net/ifaces/ens19
cat > /etc/net/ifaces/ens19/options << 'EOF'
TYPE=eth
BOOTPROTO=static
CONFIG_IPV4=yes
DISABLED=no
NM_CONTROLLED=no
SYSTEMD_CONTROLLED=no
EOF
echo "192.168.100.2/27" > /etc/net/ifaces/ens19/ipv4address
echo "default via 192.168.100.1" > /etc/net/ifaces/ens19/ipv4route
systemctl restart network && sleep 2
cat > /etc/resolv.conf << 'EOF'
nameserver 77.88.8.8
EOF
apt-get update && apt-get install -y bind bind-utils vim-console tzdata sudo
ln -sf /usr/share/zoneinfo/${TZ_REGION:-Europe/Moscow} /etc/localtime 2>/dev/null || timedatectl set-timezone ${TZ_REGION:-Europe/Moscow} 2>/dev/null || true
cat > /var/lib/bind/etc/options.conf << 'EOF'
options {
    version "unknown";
    directory "/etc/bind/zone";
    dump-file "/var/run/named/named_dump.db";
    statistics-file "/var/run/named/named.stats";
    recursing-file "/var/run/named/named.recursing";
    secroots-file "/var/run/named/named.secroots";
    pid-file none;
    listen-on { any; };
    listen-on-v6 { none; };
    recursion yes;
    allow-recursion { any; };
    forwarders { 77.88.8.8; };
    allow-query { any; };
};
EOF
cat >> /var/lib/bind/etc/rfc1912.conf << 'EOF'

zone "au-team.irpo" {
    type master;
    file "au-team.irpo";
};
zone "100.168.192.in-addr.arpa" {
    type master;
    file "100.168.192.in-addr.arpa";
};
zone "200.168.192.in-addr.arpa" {
    type master;
    file "200.168.192.in-addr.arpa";
};
EOF
cp /var/lib/bind/etc/zone/empty /var/lib/bind/etc/zone/au-team.irpo
cp /var/lib/bind/etc/zone/empty /var/lib/bind/etc/zone/100.168.192.in-addr.arpa
cp /var/lib/bind/etc/zone/empty /var/lib/bind/etc/zone/200.168.192.in-addr.arpa
cat > /var/lib/bind/etc/zone/au-team.irpo << 'EOF'
$TTL    1D
@       IN      SOA     au-team.irpo. root.au-team.irpo. (
                        2026060200      ; serial
                        12H             ; refresh
                        1H              ; retry
                        1W              ; expire
                        1H              ; ncache
                        )
        IN      NS      au-team.irpo.
        IN      A       192.168.100.2
hq-srv  IN      A       192.168.100.2
hq-cli  IN      A       192.168.200.2
hq-rtr  IN      A       192.168.100.1
hq-rtr  IN      A       192.168.200.1
hq-rtr  IN      A       192.168.99.1
docker  IN      A       172.16.1.1
web     IN      A       172.16.2.1
br-srv  IN      A       192.168.0.2
br-rtr  IN      A       192.168.0.1
EOF
cat > /var/lib/bind/etc/zone/100.168.192.in-addr.arpa << 'EOF'
$TTL    1D
@       IN      SOA     au-team.irpo. root.au-team.irpo. (
                        2026060200      ; serial
                        12H             ; refresh
                        1H              ; retry
                        1W              ; expire
                        1H              ; ncache
                        )
        IN      NS      au-team.irpo.
1       IN      PTR     hq-rtr.au-team.irpo.
2       IN      PTR     hq-srv.au-team.irpo.
EOF
cat > /var/lib/bind/etc/zone/200.168.192.in-addr.arpa << 'EOF'
$TTL    1D
@       IN      SOA     au-team.irpo. root.au-team.irpo. (
                        2026060200      ; serial
                        12H             ; refresh
                        1H              ; retry
                        1W              ; expire
                        1H              ; ncache
                        )
        IN      NS      au-team.irpo.
1       IN      PTR     hq-rtr.au-team.irpo.
2       IN      PTR     hq-cli.au-team.irpo.
EOF
rndc-confgen > /var/lib/bind/etc/rndc.key
sed -i '6,$d' /var/lib/bind/etc/rndc.key
chown -R root:named /var/lib/bind/etc/zone/*
chmod 640 /var/lib/bind/etc/zone/au-team.irpo
chmod 640 /var/lib/bind/etc/zone/100.168.192.in-addr.arpa
chmod 640 /var/lib/bind/etc/zone/200.168.192.in-addr.arpa
named-checkconf && named-checkconf -z
systemctl enable --now bind.service
cat > /etc/resolv.conf.head << EOF
search au-team.irpo
nameserver 192.168.100.2
EOF
cat > /etc/resolv.conf << EOF
search au-team.irpo
nameserver 192.168.100.2
EOF
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
ip -4 addr show ens19 2>/dev/null | grep -q "192.168.100.2" && log_info "IP 192.168.100.2: OK (VLAN 100 в Proxmox)" || log_error "IP: FAILED"
id sshuser && log_info "User: OK" || log_error "User: FAILED"
systemctl is-active bind.service > /dev/null && log_info "BIND: OK" || log_error "BIND: FAILED"
systemctl is-active sshd > /dev/null && log_info "SSH: OK" || log_error "SSH: FAILED"
echo "=== HQ-SRV Complete! ==="
