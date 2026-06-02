#!/usr/bin/env bash
# ═══ BR-RTR — LAN /28, NAT, GRE+OSPF до HQ ═══
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/../config.env"; . "$DIR/lib.sh"; need_root

set_hostname "br-rtr.$DOMAIN"
make_sudoer "$NET_USER" "" "$USER_PASS"

# Линк к ISP
ip addr flush dev "$IF_EXT" 2>/dev/null
ip addr add "$BR_ISP_IP/$BR_ISP_PFX" dev "$IF_EXT"; ip link set "$IF_EXT" up
ip route replace default via "$ISP_BR_IP" 2>/dev/null
ok "BR-RTR->ISP $BR_ISP_IP/$BR_ISP_PFX"
etcnet_eth_static "$IF_EXT" "$BR_ISP_IP/$BR_ISP_PFX" "$ISP_BR_IP"

# LAN в сторону BR-SRV (не более 16 адресов → /28)
ip addr flush dev "$IF_INT" 2>/dev/null
ip addr add "$BR_RTR_LAN/$BR_PFX" dev "$IF_INT"; ip link set "$IF_INT" up
ok "BR-LAN $BR_RTR_LAN/$BR_PFX ($IF_INT)"
etcnet_eth_static "$IF_INT" "$BR_RTR_LAN/$BR_PFX"

enable_forward

# NAT
iptables -t nat -F POSTROUTING
iptables -t nat -A POSTROUTING -o "$IF_EXT" -j MASQUERADE
iptables-save > /etc/sysconfig/iptables 2>/dev/null || true
ok "NAT через $IF_EXT"

# IP-туннель до HQ-RTR
ip tunnel del tun1 2>/dev/null; ip link del tun1 2>/dev/null
ip tunnel add tun1 mode "$TUN_TYPE" local "$BR_ISP_IP" remote "$HQ_ISP_IP"
ip addr add "$TUN_BR_IP/$TUN_PFX" dev tun1
ip link set tun1 up
ok "Туннель ($TUN_TYPE) tun1 $TUN_BR_IP/$TUN_PFX -> $TUN_HQ_IP"
etcnet_tunnel tun1 "$TUN_TYPE" "$BR_ISP_IP" "$HQ_ISP_IP" "$TUN_BR_IP/$TUN_PFX" "$IF_EXT"
etcnet_enable

# OSPF только на туннеле + пароль
pkg frr
sed -i 's/^ospfd=no/ospfd=yes/; s/^zebra=no/zebra=yes/' /etc/frr/daemons 2>/dev/null
grep -q '^ospfd=yes' /etc/frr/daemons 2>/dev/null || echo "ospfd=yes" >> /etc/frr/daemons
cat > /etc/frr/frr.conf <<EOF
frr defaults traditional
hostname br-rtr
!
interface tun1
 ip ospf authentication message-digest
 ip ospf message-digest-key $OSPF_KEY_ID md5 $OSPF_PASS
!
router ospf
 ospf router-id $TUN_BR_IP
 area $OSPF_AREA authentication message-digest
 passive-interface default
 no passive-interface tun1
 network $TUN_BR_IP/$TUN_PFX area $OSPF_AREA
 network $BR_RTR_LAN/$BR_PFX area $OSPF_AREA
!
line vty
EOF
chown frr:frr /etc/frr/frr.conf 2>/dev/null
systemctl enable --now frr 2>/dev/null && systemctl restart frr 2>/dev/null
ok "OSPF поднят только на tun1 (MD5-пароль)"

set_tz
ok "BR-RTR готов."
