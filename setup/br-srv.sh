#!/usr/bin/env bash
# ═══ BR-SRV — Альт Сервер · sshuser, SSH:2026 ═══
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/../config.env"; . "$DIR/lib.sh"; need_root

set_hostname "br-srv.$DOMAIN"

# Статический IP в BR-LAN, шлюз = BR-RTR
ip addr flush dev "$IF_INT" 2>/dev/null
ip addr add "$BR_SRV_IP/$BR_PFX" dev "$IF_INT"; ip link set "$IF_INT" up
ip route replace default via "$BR_RTR_LAN" 2>/dev/null
ok "BR-SRV $BR_SRV_IP/$BR_PFX, gw $BR_RTR_LAN"

# Задача 3: sshuser (UID 2026, sudo без пароля)
make_sudoer "$SSH_USER" "$SSH_UID" "$USER_PASS"

# Задача 5: SSH-хардненинг
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

# DNS на HQ-SRV
echo -e "search $DOMAIN\nnameserver $HQ_SRV_IP" > /etc/resolv.conf

set_tz
ok "BR-SRV готов."
