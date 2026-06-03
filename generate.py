#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
═══════════════════════════════════════════════════════════════════════
  Демоэкзамен 2026 · Модуль 1 · ГЕНЕРАТОР setup-скриптов
  Аналог формы на сайте, но локально. Меняешь данные в блоке CONFIG ниже
  (или запускаешь с --ask, чтобы ввести интерактивно) → получаешь
  6 готовых скриптов в папке out/. Сети, обратные DNS-зоны и диапазон
  DHCP считаются автоматически.

  Запуск:
      python3 generate.py            # взять данные из CONFIG ниже
      python3 generate.py --ask      # спросить значения по очереди
═══════════════════════════════════════════════════════════════════════
"""
import os, sys, ipaddress

# ╔═══════════════════════════════════════════════════════════════════╗
# ║  CONFIG — МЕНЯЙ ТОЛЬКО ЭТОТ БЛОК                                    ║
# ╚═══════════════════════════════════════════════════════════════════╝
CONFIG = {
    "domain":      "au-team.irpo",
    "timezone":    "Europe/Moscow",     # на экзамене обычно Asia/Novosibirsk

    # ── интерфейсы (узнать на машине: ip -br link) ──
    "isp_if_wan":  "ens19",   # ISP: к интернету (DHCP)
    "isp_if_hq":   "ens20",   # ISP: к HQ-RTR
    "isp_if_br":   "ens21",   # ISP: к BR-RTR
    "rtr_if_wan":  "ens19",   # роутеры: к ISP
    "hqrtr_if_lan":"ens20",   # HQ-RTR: trunk (VLAN)
    "brrtr_if_lan":"ens20",   # BR-RTR: к BR-SRV
    "srv_if":      "ens19",   # серверы/клиент: единственный интерфейс

    # ── ISP-линки (сеть/маска; .1 = ISP, .2 = роутер) ──
    "isp_hq_net":  "172.16.1.0/28",
    "isp_br_net":  "172.16.2.0/28",

    # ── VLAN главного офиса (адрес = шлюз на HQ-RTR) ──
    "vlan100_id":  100, "vlan100_gw": "192.168.100.1/27",   # серверы
    "vlan200_id":  200, "vlan200_gw": "192.168.200.1/28",   # клиенты (DHCP)
    "vlan999_id":  999, "vlan999_gw": "192.168.99.1/29",    # управление

    # ── филиал ──
    "br_lan_gw":   "192.168.0.1/28",    # шлюз на BR-RTR

    # ── адреса серверов/клиента (хостовая часть) ──
    "hq_srv_ip":   "192.168.100.2",
    "br_srv_ip":   "192.168.0.2",
    "hq_cli_ip":   "192.168.200.2",      # для DNS-записи (адрес даёт DHCP)

    # ── туннель GRE ──
    "gre_net":     "10.10.10.0/30",      # .1 = HQ, .2 = BR

    # ── прочее ──
    "ospf_key":    "1245",
    "ssh_port":    "2026",
    "ssh_user":    "sshuser",  "ssh_uid": "2026",
    "net_user":    "net_admin",
    "password":    "P@ssw0rd",
    "dns_fwd":     "77.88.8.8",
    "ssh_banner":  "Authorized access only",
}

# ╔═══════════════════════════════════════════════════════════════════╗
# ║  Дальше — логика. Менять не нужно.                                  ║
# ╚═══════════════════════════════════════════════════════════════════╝

def host(net_cidr, n):
    """n-й адрес сети: host('172.16.1.0/28',1) -> '172.16.1.1'"""
    net = ipaddress.ip_network(net_cidr, strict=False)
    return str(net.network_address + n)

def pfx(cidr):
    return cidr.split("/")[1]

def netonly(cidr):
    return str(ipaddress.ip_network(cidr, strict=False).network_address) + "/" + pfx(cidr)

def ip_of(gw_cidr):
    return gw_cidr.split("/")[0]

def netmask(cidr):
    return str(ipaddress.ip_network(cidr, strict=False).netmask)

def net_addr(cidr):
    return str(ipaddress.ip_network(cidr, strict=False).network_address)

def dhcp_range(gw_cidr):
    net = ipaddress.ip_network(gw_cidr, strict=False)
    hosts = list(net.hosts())
    return str(hosts[1]), str(hosts[-1])     # с .2 до последнего

def rev_zone(ip):
    p = ip.split("."); return f"{p[2]}.{p[1]}.{p[0]}.in-addr.arpa"

def last_octet(ip):
    return ip.split(".")[-1]

def ask_config(c):
    print("Ввод значений (Enter = оставить текущее в скобках):\n")
    for k in c:
        cur = c[k]
        v = input(f"  {k} [{cur}]: ").strip()
        if v: c[k] = type(cur)(v) if isinstance(cur, int) else v
    return c

# ── вычисляемые значения ──
def derive(c):
    d = dict(c)
    d["isp_hq_ip"]   = host(c["isp_hq_net"], 1)
    d["hqrtr_wan"]   = host(c["isp_hq_net"], 2)
    d["isp_br_ip"]   = host(c["isp_br_net"], 1)
    d["brrtr_wan"]   = host(c["isp_br_net"], 2)
    d["gre_hq"]      = host(c["gre_net"], 1)
    d["gre_br"]      = host(c["gre_net"], 2)
    d["isp_hq_pfx"]  = pfx(c["isp_hq_net"])
    d["isp_br_pfx"]  = pfx(c["isp_br_net"])
    d["gre_pfx"]     = pfx(c["gre_net"])
    d["br_lan_net"]  = netonly(c["br_lan_gw"])
    d["v100_net"]    = netonly(c["vlan100_gw"]); d["v100_ip"]=ip_of(c["vlan100_gw"]); d["v100_pfx"]=pfx(c["vlan100_gw"])
    d["v200_net"]    = netonly(c["vlan200_gw"]); d["v200_ip"]=ip_of(c["vlan200_gw"]); d["v200_pfx"]=pfx(c["vlan200_gw"])
    d["v999_net"]    = netonly(c["vlan999_gw"]); d["v999_ip"]=ip_of(c["vlan999_gw"]); d["v999_pfx"]=pfx(c["vlan999_gw"])
    d["br_gw_ip"]    = ip_of(c["br_lan_gw"]); d["br_pfx"]=pfx(c["br_lan_gw"])
    d["dhcp_start"], d["dhcp_end"] = dhcp_range(c["vlan200_gw"])
    d["v200_netaddr"]= net_addr(c["vlan200_gw"]); d["v200_mask"]=netmask(c["vlan200_gw"])
    d["rev_srv"]     = rev_zone(c["hq_srv_ip"])
    d["rev_cli"]     = rev_zone(c["hq_cli_ip"])
    return d

HEADER = """#!/bin/bash
# {title} - ALT Linux (etcnet) | DEMO-2026 (сгенерировано generate.py)
set -e
TZ_REGION="${{TZ_REGION:-{tz}}}"
RED='\\033[0;31m'; GREEN='\\033[0;32m'; YELLOW='\\033[1;33m'; BLUE='\\033[0;34m'; NC='\\033[0m'
log_info() {{ echo -e "${{GREEN}}[INFO]${{NC}} $1"; }}
log_warn() {{ echo -e "${{YELLOW}}[WARN]${{NC}} $1"; }}
log_error() {{ echo -e "${{RED}}[ERROR]${{NC}} $1"; }}
log_step() {{ echo -e "${{BLUE}}[STEP]${{NC}} $1"; }}
[[ $EUID -ne 0 ]] && {{ log_error "Run as root!"; exit 1; }}
echo "===== {title} ====="
hostnamectl set-hostname {host}.{domain}
"""

def eth_static(ifc, addr, gw=None):
    s = f"""mkdir -p /etc/net/ifaces/{ifc}
cat > /etc/net/ifaces/{ifc}/options << 'EOF'
TYPE=eth
BOOTPROTO=static
DISABLED=no
NM_CONTROLLED=no
SYSTEMD_CONTROLLED=no
CONFIG_IPV4=yes
EOF
echo "{addr}" > /etc/net/ifaces/{ifc}/ipv4address
"""
    if gw: s += f'echo "default via {gw}" > /etc/net/ifaces/{ifc}/ipv4route\n'
    return s

def eth_dhcp(ifc):
    return f"""mkdir -p /etc/net/ifaces/{ifc}
cat > /etc/net/ifaces/{ifc}/options << 'EOF'
TYPE=eth
BOOTPROTO=dhcp
CONFIG_WIRELESS=no
SYSTEMD_BOOTPROTO=dhcp4
CONFIG_IPV4=yes
DISABLED=no
NM_CONTROLLED=no
SYSTEMD_CONTROLLED=no
EOF
"""

FWD_ON = """grep -q "^net.ipv4.ip_forward" /etc/net/sysctl.conf && sed -i 's/^net.ipv4.ip_forward.*/net.ipv4.ip_forward = 1/' /etc/net/sysctl.conf || echo "net.ipv4.ip_forward = 1" >> /etc/net/sysctl.conf
sysctl -w net.ipv4.ip_forward=1 > /dev/null
"""

def sudoer(user, uid=None):
    add = f"useradd -m -u {uid} {user}" if uid else f"useradd -m {user}"
    return f"""{add} 2>/dev/null || log_warn "user exists"
echo '{user}:{{password}}' | chpasswd
usermod -a -G wheel {user}
sed -i 's/^#WHEEL_USERS ALL=(ALL:ALL) NOPASSWD: ALL/WHEEL_USERS ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
sed -i 's/^# WHEEL_USERS ALL=(ALL:ALL) NOPASSWD: ALL/WHEEL_USERS ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
"""

def ssh_hardening(d):
    return f"""sed -i 's/^#Port 22/Port {d['ssh_port']}/' /etc/openssh/sshd_config
sed -i 's/^Port 22/Port {d['ssh_port']}/' /etc/openssh/sshd_config
grep -q "^AllowUsers" /etc/openssh/sshd_config || echo "AllowUsers {d['ssh_user']}" >> /etc/openssh/sshd_config
grep -q "^MaxAuthTries" /etc/openssh/sshd_config || echo "MaxAuthTries 2" >> /etc/openssh/sshd_config
grep -q "^Banner" /etc/openssh/sshd_config || echo "Banner /etc/openssh/banner" >> /etc/openssh/sshd_config
echo "{d['ssh_banner']}" > /etc/openssh/banner
systemctl restart sshd
"""

# ─────────────────────────── ISP ───────────────────────────
def gen_isp(d):
    s = HEADER.format(title="ISP", host="isp", domain=d["domain"], tz=d["timezone"])
    s += eth_dhcp(d["isp_if_wan"])
    s += eth_static(d["isp_if_hq"], f'{d["isp_hq_ip"]}/{d["isp_hq_pfx"]}')
    s += eth_static(d["isp_if_br"], f'{d["isp_br_ip"]}/{d["isp_br_pfx"]}')
    s += FWD_ON
    s += "apt-get update && apt-get install -y iptables vim tzdata || true\n"
    s += f"""iptables -t nat -F POSTROUTING 2>/dev/null || true
iptables -t nat -A POSTROUTING -s {d['isp_hq_net']} -o {d['isp_if_wan']} -j MASQUERADE
iptables -t nat -A POSTROUTING -s {d['isp_br_net']} -o {d['isp_if_wan']} -j MASQUERADE
mkdir -p /etc/sysconfig && iptables-save > /etc/sysconfig/iptables
systemctl enable --now iptables 2>/dev/null || true
timedatectl set-timezone ${{TZ_REGION}}
systemctl restart network && sleep 3
ping -c2 -W2 {d['dns_fwd']} >/dev/null 2>&1 && log_info "Internet OK" || log_warn "no internet"
echo "=== ISP done ==="
"""
    return s

# ─────────────────────────── HQ-RTR ───────────────────────────
def gen_hqrtr(d):
    s = HEADER.format(title="HQ-RTR", host="hq-rtr", domain=d["domain"], tz=d["timezone"])
    s += eth_static(d["rtr_if_wan"], f'{d["hqrtr_wan"]}/{d["isp_hq_pfx"]}', d["isp_hq_ip"])
    # trunk без IP
    s += f"""mkdir -p /etc/net/ifaces/{d['hqrtr_if_lan']}
cat > /etc/net/ifaces/{d['hqrtr_if_lan']}/options << 'EOF'
TYPE=eth
BOOTPROTO=static
DISABLED=no
NM_CONTROLLED=no
SYSTEMD_CONTROLLED=no
EOF
"""
    for vid, ipp in [(d["vlan100_id"], d["vlan100_gw"]),
                     (d["vlan200_id"], d["vlan200_gw"]),
                     (d["vlan999_id"], d["vlan999_gw"])]:
        sub = f"{d['hqrtr_if_lan']}.{vid}"
        s += f"""mkdir -p /etc/net/ifaces/{sub}
cat > /etc/net/ifaces/{sub}/options << EOF
TYPE=vlan
HOST={d['hqrtr_if_lan']}
VID={vid}
DISABLED=no
BOOTPROTO=static
ONBOOT=yes
CONFIG_IPV4=yes
EOF
echo "{ipp}" > /etc/net/ifaces/{sub}/ipv4address
"""
    s += FWD_ON
    s += f"""systemctl restart network && sleep 2
cat > /etc/resolv.conf << 'EOF'
nameserver {d['dns_fwd']}
EOF
ping -c2 -W3 {d['dns_fwd']} >/dev/null 2>&1 && log_info "Internet OK" || {{ log_error "no internet"; exit 1; }}
apt-get update
apt-get install -y iptables frr dhcp-server vim tzdata sudo
timedatectl set-timezone ${{TZ_REGION}}
"""
    s += sudoer(d["net_user"]).replace("{password}", d["password"])
    s += f"""iptables -t nat -F POSTROUTING 2>/dev/null || true
iptables -t nat -A POSTROUTING -o {d['rtr_if_wan']} -s {d['v100_net']} -j MASQUERADE
iptables -t nat -A POSTROUTING -o {d['rtr_if_wan']} -s {d['v200_net']} -j MASQUERADE
mkdir -p /etc/sysconfig && iptables-save > /etc/sysconfig/iptables
systemctl enable --now iptables 2>/dev/null || true
mkdir -p /etc/net/ifaces/gre1
cat > /etc/net/ifaces/gre1/options << EOF
TYPE=iptun
TUNTYPE=gre
TUNLOCAL={d['hqrtr_wan']}
TUNREMOTE={d['brrtr_wan']}
TUNOPTIONS='ttl 64'
HOST={d['rtr_if_wan']}
BOOTPROTO=static
DISABLED=no
CONFIG_IPV4=yes
EOF
echo "{d['gre_hq']}/{d['gre_pfx']}" > /etc/net/ifaces/gre1/ipv4address
sed -i 's/^ospfd=no/ospfd=yes/; s/^#ospfd=no/ospfd=yes/' /etc/frr/daemons
systemctl enable frr && systemctl restart frr && sleep 2
vtysh << 'VTYSH_EOF'
configure terminal
router ospf
  passive-interface default
  network {d['gre_net']} area 0
  network {d['v100_net']} area 0
  network {d['v200_net']} area 0
  area 0 authentication
exit
interface gre1
  no ip ospf passive
  ip ospf authentication-key {d['ospf_key']}
exit
do write
end
VTYSH_EOF
cat > /etc/dhcp/dhcpd.conf << EOF
ddns-update-style none;
subnet {d['v200_netaddr']} netmask {d['v200_mask']}
{{
    option routers                  {d['v200_ip']};
    option subnet-mask              {d['v200_mask']};
    option domain-name-servers      {d['hq_srv_ip']};
    option domain-name              "{d['domain']}";
    range dynamic-bootp             {d['dhcp_start']} {d['dhcp_end']};
    default-lease-time              21600;
    max-lease-time                  43200;
}}
EOF
echo "DHCPDARGS={d['hqrtr_if_lan']}.{d['vlan200_id']}" > /etc/sysconfig/dhcpd
systemctl enable dhcpd
systemctl restart network && sleep 3
systemctl restart frr && sleep 2
cat > /etc/resolv.conf << EOF
search {d['domain']}
nameserver {d['hq_srv_ip']}
EOF
systemctl restart dhcpd || log_warn "dhcp check"
echo "=== HQ-RTR done ==="
"""
    return s

# ─────────────────────────── BR-RTR ───────────────────────────
def gen_brrtr(d):
    s = HEADER.format(title="BR-RTR", host="br-rtr", domain=d["domain"], tz=d["timezone"])
    s += eth_static(d["rtr_if_wan"], f'{d["brrtr_wan"]}/{d["isp_br_pfx"]}', d["isp_br_ip"])
    s += eth_static(d["brrtr_if_lan"], f'{d["br_gw_ip"]}/{d["br_pfx"]}')
    s += FWD_ON
    s += f"""systemctl restart network && sleep 2
cat > /etc/resolv.conf << 'EOF'
nameserver {d['dns_fwd']}
EOF
ping -c2 -W3 {d['dns_fwd']} >/dev/null 2>&1 && log_info "Internet OK" || {{ log_error "no internet"; exit 1; }}
apt-get update
apt-get install -y iptables frr vim tzdata sudo
timedatectl set-timezone ${{TZ_REGION}}
"""
    s += sudoer(d["net_user"]).replace("{password}", d["password"])
    s += f"""iptables -t nat -F POSTROUTING 2>/dev/null || true
iptables -t nat -A POSTROUTING -o {d['rtr_if_wan']} -s {d['br_lan_net']} -j MASQUERADE
mkdir -p /etc/sysconfig && iptables-save > /etc/sysconfig/iptables
systemctl enable --now iptables 2>/dev/null || true
mkdir -p /etc/net/ifaces/gre1
cat > /etc/net/ifaces/gre1/options << EOF
TYPE=iptun
TUNTYPE=gre
TUNLOCAL={d['brrtr_wan']}
TUNREMOTE={d['hqrtr_wan']}
TUNOPTIONS='ttl 64'
HOST={d['rtr_if_wan']}
BOOTPROTO=static
DISABLED=no
CONFIG_IPV4=yes
EOF
echo "{d['gre_br']}/{d['gre_pfx']}" > /etc/net/ifaces/gre1/ipv4address
sed -i 's/^ospfd=no/ospfd=yes/; s/^#ospfd=no/ospfd=yes/' /etc/frr/daemons
systemctl enable frr && systemctl restart frr && sleep 2
vtysh << 'VTYSH_EOF'
configure terminal
router ospf
  passive-interface default
  network {d['gre_net']} area 0
  network {d['br_lan_net']} area 0
  area 0 authentication
exit
interface gre1
  no ip ospf passive
  ip ospf authentication-key {d['ospf_key']}
exit
do write
end
VTYSH_EOF
systemctl restart network && sleep 3
systemctl restart frr && sleep 2
cat > /etc/resolv.conf << EOF
search {d['domain']}
nameserver {d['hq_srv_ip']}
EOF
echo "=== BR-RTR done ==="
"""
    return s

# ─────────────────────────── HQ-SRV ───────────────────────────
def gen_hqsrv(d):
    s = HEADER.format(title="HQ-SRV", host="hq-srv", domain=d["domain"], tz=d["timezone"])
    s += eth_static(d["srv_if"], f'{d["hq_srv_ip"]}/{d["v100_pfx"]}', d["v100_ip"])
    s += f"""systemctl restart network && sleep 2
cat > /etc/resolv.conf << 'EOF'
nameserver {d['dns_fwd']}
EOF
apt-get update && apt-get install -y bind bind-utils vim tzdata sudo
timedatectl set-timezone ${{TZ_REGION}}
cat > /var/lib/bind/etc/options.conf << 'EOF'
options {{
    version "unknown";
    directory "/etc/bind/zone";
    listen-on {{ any; }};
    listen-on-v6 {{ none; }};
    recursion yes;
    allow-recursion {{ any; }};
    forwarders {{ {d['dns_fwd']}; }};
    allow-query {{ any; }};
}};
EOF
cat >> /var/lib/bind/etc/rfc1912.conf << 'EOF'

zone "{d['domain']}" {{ type master; file "{d['domain']}"; }};
zone "{d['rev_srv']}" {{ type master; file "{d['rev_srv']}"; }};
zone "{d['rev_cli']}" {{ type master; file "{d['rev_cli']}"; }};
EOF
cp /var/lib/bind/etc/zone/empty /var/lib/bind/etc/zone/{d['domain']}
cp /var/lib/bind/etc/zone/empty /var/lib/bind/etc/zone/{d['rev_srv']}
cp /var/lib/bind/etc/zone/empty /var/lib/bind/etc/zone/{d['rev_cli']}
cat > /var/lib/bind/etc/zone/{d['domain']} << EOF
\\$TTL 1D
@   IN SOA {d['domain']}. root.{d['domain']}. ( 2026060200 12H 1H 1W 1H )
    IN NS  {d['domain']}.
    IN A   {d['hq_srv_ip']}
hq-srv IN A {d['hq_srv_ip']}
hq-cli IN A {d['hq_cli_ip']}
hq-rtr IN A {d['v100_ip']}
hq-rtr IN A {d['v200_ip']}
hq-rtr IN A {d['v999_ip']}
docker IN A {d['isp_hq_ip']}
web    IN A {d['isp_br_ip']}
br-srv IN A {d['br_srv_ip']}
br-rtr IN A {d['br_gw_ip']}
EOF
cat > /var/lib/bind/etc/zone/{d['rev_srv']} << EOF
\\$TTL 1D
@   IN SOA {d['domain']}. root.{d['domain']}. ( 2026060200 12H 1H 1W 1H )
    IN NS {d['domain']}.
{last_octet(d['v100_ip'])} IN PTR hq-rtr.{d['domain']}.
{last_octet(d['hq_srv_ip'])} IN PTR hq-srv.{d['domain']}.
EOF
cat > /var/lib/bind/etc/zone/{d['rev_cli']} << EOF
\\$TTL 1D
@   IN SOA {d['domain']}. root.{d['domain']}. ( 2026060200 12H 1H 1W 1H )
    IN NS {d['domain']}.
{last_octet(d['v200_ip'])} IN PTR hq-rtr.{d['domain']}.
{last_octet(d['hq_cli_ip'])} IN PTR hq-cli.{d['domain']}.
EOF
rndc-confgen > /var/lib/bind/etc/rndc.key && sed -i '6,$d' /var/lib/bind/etc/rndc.key
chown -R root:named /var/lib/bind/etc/zone/*
named-checkconf && named-checkconf -z
systemctl enable --now bind.service
cat > /etc/resolv.conf << EOF
search {d['domain']}
nameserver {d['hq_srv_ip']}
EOF
"""
    s += sudoer(d["ssh_user"], d["ssh_uid"]).replace("{password}", d["password"])
    s += ssh_hardening(d)
    s += 'echo "=== HQ-SRV done ==="\n'
    return s

# ─────────────────────────── BR-SRV ───────────────────────────
def gen_brsrv(d):
    s = HEADER.format(title="BR-SRV", host="br-srv", domain=d["domain"], tz=d["timezone"])
    s += eth_static(d["srv_if"], f'{d["br_srv_ip"]}/{d["br_pfx"]}', d["br_gw_ip"])
    s += f"""systemctl restart network && sleep 2
cat > /etc/resolv.conf << EOF
search {d['domain']}
nameserver {d['hq_srv_ip']}
EOF
apt-get update || true
apt-get install -y vim tzdata sudo || true
timedatectl set-timezone ${{TZ_REGION}}
"""
    s += sudoer(d["ssh_user"], d["ssh_uid"]).replace("{password}", d["password"])
    s += ssh_hardening(d)
    s += 'echo "=== BR-SRV done ==="\n'
    return s

# ─────────────────────────── HQ-CLI ───────────────────────────
def gen_hqcli(d):
    s = HEADER.format(title="HQ-CLI", host="hq-cli", domain=d["domain"], tz=d["timezone"])
    s += "# VLAN ID назначается в Proxmox (Hardware -> Network -> VLAN Tag)\n"
    s += eth_dhcp(d["srv_if"])
    s += f"""cat > /etc/resolv.conf << EOF
search {d['domain']}
nameserver {d['hq_srv_ip']}
EOF
systemctl restart network && sleep 3
cat > /etc/resolv.conf << EOF
search {d['domain']}
nameserver {d['hq_srv_ip']}
EOF
apt-get update || true
apt-get install -y vim tzdata || true
timedatectl set-timezone ${{TZ_REGION}}
ip -4 addr show {d['srv_if']} | grep -q "inet " && log_info "DHCP OK" || log_error "DHCP FAILED"
echo "=== HQ-CLI done ==="
"""
    return s

GENS = {"isp": gen_isp, "hq-rtr": gen_hqrtr, "br-rtr": gen_brrtr,
        "hq-srv": gen_hqsrv, "br-srv": gen_brsrv, "hq-cli": gen_hqcli}

def main():
    c = dict(CONFIG)
    if "--ask" in sys.argv:
        c = ask_config(c)
    d = derive(c)
    os.makedirs("out", exist_ok=True)
    for role, fn in GENS.items():
        path = os.path.join("out", f"{role}.sh")
        with open(path, "w", newline="\n") as f:   # newline=\n => LF, не CRLF
            f.write(fn(d))
        os.chmod(path, 0o755)
        print(f"  ✓ out/{role}.sh")
    print("\nГотово. Скрипты в папке out/ (с LF). Запуск на машине: sudo bash out/<роль>.sh")

if __name__ == "__main__":
    main()
