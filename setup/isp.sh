#!/usr/bin/env bash
# ═══ ISP — Альт JeOS · uplink по DHCP, /28 к HQ и BR, динамический NAT (PAT) ═══
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/../config.env"; . "$DIR/lib.sh"; need_root

set_hostname "isp.$DOMAIN"

# Задача 2: внешний интерфейс по DHCP, два внутренних /28
[ "$ISP_UPLINK_DHCP" = 1 ] && { log "Uplink ($IF_EXT) по DHCP"; dhcp_up "$IF_EXT"; }

# Внутренние интерфейсы к роутерам офисов.
# По умолчанию: IF_INT -> HQ. Второй линк к BR задай через IF_INT2 в config.env при необходимости.
IF_INT2="${IF_INT2:-ens20}"
ip addr flush dev "$IF_INT"  2>/dev/null
ip addr add "$ISP_HQ_IP/$ISP_HQ_PFX" dev "$IF_INT";  ip link set "$IF_INT" up
ip addr flush dev "$IF_INT2" 2>/dev/null
ip addr add "$ISP_BR_IP/$ISP_BR_PFX" dev "$IF_INT2"; ip link set "$IF_INT2" up
ok "ISP->HQ $ISP_HQ_IP/$ISP_HQ_PFX ($IF_INT), ISP->BR $ISP_BR_IP/$ISP_BR_PFX ($IF_INT2)"

enable_forward

# Задача 2/8: динамический NAT (маскарад) в сторону интернета
iptables -t nat -F POSTROUTING
iptables -t nat -A POSTROUTING -o "$IF_EXT" -j MASQUERADE
# сохранить правила
mkdir -p /etc/sysconfig
iptables-save > /etc/sysconfig/iptables 2>/dev/null || true
ok "Динамический NAT через $IF_EXT настроен"

set_tz
ok "ISP готов. Проверь: ping -c1 77.88.8.8"
