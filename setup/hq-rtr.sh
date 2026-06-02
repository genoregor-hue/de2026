#!/usr/bin/env bash
# ═══ HQ-RTR — router-on-a-stick (VLAN 100/200/999), NAT, GRE+OSPF, DHCP ═══
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/../config.env"; . "$DIR/lib.sh"; need_root

set_hostname "hq-rtr.$DOMAIN"

# Задача 3: пользователь net_admin
make_sudoer "$NET_USER" "" "$USER_PASS"

# Линк к ISP
ip addr flush dev "$IF_EXT" 2>/dev/null
ip addr add "$HQ_ISP_IP/$HQ_ISP_PFX" dev "$IF_EXT"; ip link set "$IF_EXT" up
ip route replace default via "$ISP_HQ_IP" 2>/dev/null
ok "HQ-RTR->ISP $HQ_ISP_IP/$HQ_ISP_PFX"
etcnet_eth_static "$IF_EXT" "$HQ_ISP_IP/$HQ_ISP_PFX" "$ISP_HQ_IP"
etcnet_eth_trunk "$IF_INT"

enable_forward

# Задача 4: router-on-a-stick — VLAN-сабинтерфейсы на ОДНОМ физ. интерфейсе ($IF_INT)
ip link set "$IF_INT" up
modprobe 8021q 2>/dev/null
for v in "$VL100_ID:$VL100_RTR:$VL100_PFX" "$VL200_ID:$VL200_RTR:$VL200_PFX" "$VL999_ID:$VL999_RTR:$VL999_PFX"; do
  id="${v%%:*}"; rest="${v#*:}"; rtr="${rest%%:*}"; pfx="${rest##*:}"
  ip link del "$IF_INT.$id" 2>/dev/null
  ip link add link "$IF_INT" name "$IF_INT.$id" type vlan id "$id"
  ip addr add "$rtr/$pfx" dev "$IF_INT.$id"
  ip link set "$IF_INT.$id" up
  etcnet_vlan "$IF_INT" "$id" "$rtr/$pfx"
  ok "VLAN $id -> $rtr/$pfx ($IF_INT.$id)"
done

# Задача 8: NAT для офиса в сторону ISP
iptables -t nat -F POSTROUTING
iptables -t nat -A POSTROUTING -o "$IF_EXT" -j MASQUERADE
iptables-save > /etc/sysconfig/iptables 2>/dev/null || true
ok "NAT через $IF_EXT"

# Задача 6: IP-туннель (GRE/IPIP) до BR-RTR
ip tunnel del tun1 2>/dev/null; ip link del tun1 2>/dev/null
ip tunnel add tun1 mode "$TUN_TYPE" local "$HQ_ISP_IP" remote "$BR_ISP_IP"
ip addr add "$TUN_HQ_IP/$TUN_PFX" dev tun1
ip link set tun1 up
ok "Туннель ($TUN_TYPE) tun1 $TUN_HQ_IP/$TUN_PFX -> $TUN_BR_IP"
etcnet_tunnel tun1 "$TUN_TYPE" "$HQ_ISP_IP" "$BR_ISP_IP" "$TUN_HQ_IP/$TUN_PFX" "$IF_EXT"
etcnet_enable

# Задача 7: OSPF (FRR) только на туннеле + парольная защита
pkg frr
sed -i 's/^ospfd=no/ospfd=yes/; s/^zebra=no/zebra=yes/' /etc/frr/daemons 2>/dev/null
grep -q '^ospfd=yes' /etc/frr/daemons 2>/dev/null || echo "ospfd=yes" >> /etc/frr/daemons
cat > /etc/frr/frr.conf <<EOF
frr defaults traditional
hostname hq-rtr
!
interface tun1
 ip ospf authentication message-digest
 ip ospf message-digest-key $OSPF_KEY_ID md5 $OSPF_PASS
!
router ospf
 ospf router-id $TUN_HQ_IP
 area $OSPF_AREA authentication message-digest
 passive-interface default
 no passive-interface tun1
 network $TUN_HQ_IP/$TUN_PFX area $OSPF_AREA
 network $VL100_RTR/$VL100_PFX area $OSPF_AREA
 network $VL200_RTR/$VL200_PFX area $OSPF_AREA
 network $VL999_RTR/$VL999_PFX area $OSPF_AREA
!
line vty
EOF
chown frr:frr /etc/frr/frr.conf 2>/dev/null
systemctl enable --now frr 2>/dev/null && systemctl restart frr 2>/dev/null
ok "OSPF поднят только на tun1 (MD5-пароль)"

# Задача 9: DHCP-сервер для VLAN 200 (HQ-CLI), DNS=HQ-SRV, суффикс=домен, шлюз=HQ-RTR
pkg dhcp-server
CONF=/etc/dhcp/dhcpd.conf
[ -f "$CONF" ] || CONF=/etc/dhcpd.conf
mkdir -p "$(dirname "$CONF")"
cat > "$CONF" <<EOF
authoritative;
option domain-name "$DOMAIN";
option domain-name-servers $HQ_SRV_IP;
default-lease-time 600;
max-lease-time 7200;

subnet $VL200_NET netmask $(ipcalc_mask) {
  range $(dhcp_range);
  option routers $VL200_RTR;          # шлюз = HQ-RTR
  option domain-name-servers $HQ_SRV_IP;
  option domain-name "$DOMAIN";
}
EOF
# адрес роутера исключён, т.к. не входит в range (range начинается с .2)
echo "INTERFACES=\"$IF_INT.$VL200_ID\"" > /etc/sysconfig/dhcpd 2>/dev/null || true
systemctl enable --now dhcpd 2>/dev/null && systemctl restart dhcpd 2>/dev/null
ok "DHCP для VLAN200 на $IF_INT.$VL200_ID"

set_tz
ok "HQ-RTR готов."
