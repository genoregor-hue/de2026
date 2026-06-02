#!/usr/bin/env bash
# ═══ HQ-SRV — Альт Сервер · sshuser, SSH:2026, основной DNS (BIND) ═══
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/../config.env"; . "$DIR/lib.sh"; need_root

set_hostname "hq-srv.$DOMAIN"

# Статический IP в VLAN100, шлюз = HQ-RTR
ip addr flush dev "$IF_INT" 2>/dev/null
ip addr add "$HQ_SRV_IP/$VL100_PFX" dev "$IF_INT"; ip link set "$IF_INT" up
ip route replace default via "$VL100_RTR" 2>/dev/null
ok "HQ-SRV $HQ_SRV_IP/$VL100_PFX, gw $VL100_RTR"
etcnet_eth_static "$IF_INT" "$HQ_SRV_IP/$VL100_PFX" "$VL100_RTR"
etcnet_enable

# Задача 3: sshuser (UID 2026, sudo без пароля)
make_sudoer "$SSH_USER" "$SSH_UID" "$USER_PASS"

# Задача 5: безопасный SSH — порт 2026, только sshuser, 2 попытки, баннер
SSHD=/etc/openssh/sshd_config; [ -f "$SSHD" ] || SSHD=/etc/ssh/sshd_config
echo "$SSH_BANNER_TEXT" > /etc/openssh/banner 2>/dev/null || echo "$SSH_BANNER_TEXT" > /etc/ssh/banner
BANNER_PATH=/etc/openssh/banner; [ -f /etc/ssh/banner ] && BANNER_PATH=/etc/ssh/banner
sed -i -E '/^#?(Port|AllowUsers|MaxAuthTries|Banner|PermitRootLogin)\b/d' "$SSHD"
cat >> "$SSHD" <<EOF

# --- Демоэкзамен 2026 ---
Port $SSH_PORT
AllowUsers $SSH_USER
MaxAuthTries 2
Banner $BANNER_PATH
EOF
systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
ok "SSH: порт $SSH_PORT, только $SSH_USER, MaxAuthTries 2, баннер"

# Задача 10: основной DNS на BIND — прямая и обратная зоны + forwarder
pkg bind
NAMEDIR=/var/lib/bind/etc; [ -d /etc/bind ] && NAMEDIR=/etc/bind
ZONEDIR=/var/lib/bind/zone; mkdir -p "$ZONEDIR"
# обратная зона из сети VLAN100
REV_OCT="$(echo "$HQ_SRV_IP" | cut -d. -f3).$(echo "$HQ_SRV_IP" | cut -d. -f2).$(echo "$HQ_SRV_IP" | cut -d. -f1)"
NET3="$(echo "$HQ_SRV_IP" | cut -d. -f1-3)"

cat > /etc/bind/options.conf 2>/dev/null <<EOF || true
options {
    directory "/var/lib/bind";
    listen-on { any; };
    allow-query { any; };
    recursion yes;
    forwarders { $DNS_FORWARDER_1; $DNS_FORWARDER_2; };
    forward first;
    dnssec-validation no;
};
EOF

# Подключаем зоны
cat > /etc/bind/local.conf 2>/dev/null <<EOF || true
zone "$DOMAIN" {
    type master;
    file "$ZONEDIR/db.$DOMAIN";
};
zone "$REV_OCT.in-addr.arpa" {
    type master;
    file "$ZONEDIR/db.rev";
};
EOF

# Прямая зона
cat > "$ZONEDIR/db.$DOMAIN" <<EOF
\$TTL 3600
@   IN SOA hq-srv.$DOMAIN. root.$DOMAIN. ( 2026010101 3600 600 86400 3600 )
@         IN NS  hq-srv.$DOMAIN.
hq-srv    IN A   $HQ_SRV_IP
hq-rtr    IN A   $VL100_RTR
hq-cli    IN A   ${VL200_NET%.*}.2
br-rtr    IN A   $TUN_BR_IP
br-srv    IN A   $BR_SRV_IP
docker    IN A   $BR_SRV_IP
web       IN A   $BR_SRV_IP
EOF

# Обратная зона (для серверов HQ)
HOST_OCT="$(echo "$HQ_SRV_IP" | cut -d. -f4)"
RTR_OCT="$(echo "$VL100_RTR" | cut -d. -f4)"
cat > "$ZONEDIR/db.rev" <<EOF
\$TTL 3600
@   IN SOA hq-srv.$DOMAIN. root.$DOMAIN. ( 2026010101 3600 600 86400 3600 )
@   IN NS  hq-srv.$DOMAIN.
$HOST_OCT  IN PTR hq-srv.$DOMAIN.
$RTR_OCT   IN PTR hq-rtr.$DOMAIN.
EOF

chown -R named:named "$ZONEDIR" /etc/bind 2>/dev/null || true
systemctl enable --now bind 2>/dev/null || systemctl enable --now named 2>/dev/null
systemctl restart bind 2>/dev/null || systemctl restart named 2>/dev/null
ok "DNS (BIND): прямая+обратная зоны, forwarder $DNS_FORWARDER_1"

# локальный resolv на себя
echo -e "search $DOMAIN\nnameserver $HQ_SRV_IP" > /etc/resolv.conf

set_tz
ok "HQ-SRV готов. Проверь: dig hq-srv.$DOMAIN @$HQ_SRV_IP"
