#!/usr/bin/env bash
# ═══ HQ-CLI — Альт Рабочая Станция · клиент DHCP в VLAN 200 ═══
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/../config.env"; . "$DIR/lib.sh"; need_root

set_hostname "hq-cli.$DOMAIN"

# Задача 9: получить адрес по DHCP от HQ-RTR (шлюз, DNS, суффикс придут от сервера)
ip addr flush dev "$IF_INT" 2>/dev/null
ip link set "$IF_INT" up
(dhcpcd "$IF_INT" || dhclient "$IF_INT") >/dev/null 2>&1
sleep 3
ok "HQ-CLI: запрошен адрес по DHCP на $IF_INT"
etcnet_eth_dhcp "$IF_INT"
etcnet_enable
ip -4 -br addr show "$IF_INT"

set_tz
echo
log "Проверь: cat /etc/resolv.conf  (должен быть DNS $HQ_SRV_IP и суффикс $DOMAIN)"
log "         nslookup hq-srv.$DOMAIN"
ok "HQ-CLI готов."
