#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  etcnet-генератор (/etc/net/ifaces/) для Альт Linux.
#  Делает конфиг постоянным (переживает ребут). Сетевую службу НЕ
#  перезапускаем внутри скрипта (чтобы не уронить сессию) — только
#  включаем на следующую загрузку; текущая сессия живёт на `ip ...`.
# ════════════════════════════════════════════════════════════════════

ETCNET="/etc/net/ifaces"

# Базовый options-файл для интерфейса
_etcnet_opts() {            # $1=dir  $2=TYPE  $3=BOOTPROTO  [extra lines via stdin]
  local dir="$1" type="$2" boot="$3"
  mkdir -p "$dir"
  {
    echo "TYPE=$type"
    echo "BOOTPROTO=$boot"
    echo "ONBOOT=yes"
    echo "CONFIG_IPV4=yes"
    echo "DISABLED=no"
    cat   # доп. строки (HOST/VID/TUN*), если переданы через stdin
  } > "$dir/options"
}

# Обычный ethernet с статикой
etcnet_eth_static() {       # $1=iface  $2=ip/pfx  [$3=gw]
  local d="$ETCNET/$1"
  : | _etcnet_opts "$d" eth static
  echo "$2" > "$d/ipv4address"
  [ -n "${3:-}" ] && echo "default via $3" > "$d/ipv4route"
  ok "etcnet: $1 static $2 ${3:+(gw $3)}"
}

# Ethernet по DHCP
etcnet_eth_dhcp() {         # $1=iface
  local d="$ETCNET/$1"
  : | _etcnet_opts "$d" eth dhcp
  rm -f "$d/ipv4address" "$d/ipv4route" 2>/dev/null
  ok "etcnet: $1 dhcp"
}

# Транковый родитель для VLAN (поднимается без IP)
etcnet_eth_trunk() {        # $1=iface
  local d="$ETCNET/$1"
  : | _etcnet_opts "$d" eth static
  rm -f "$d/ipv4address" "$d/ipv4route" 2>/dev/null
  ok "etcnet: $1 trunk (без IP)"
}

# VLAN-сабинтерфейс
etcnet_vlan() {             # $1=parent  $2=vid  $3=ip/pfx
  local d="$ETCNET/$1.$2"
  printf 'HOST=%s\nVID=%s\n' "$1" "$2" | _etcnet_opts "$d" vlan static
  echo "$3" > "$d/ipv4address"
  ok "etcnet: VLAN $2 на $1 -> $3"
}

# IP-туннель (gre/ipip)
etcnet_tunnel() {           # $1=name $2=type $3=local $4=remote $5=ip/pfx $6=host_iface
  local d="$ETCNET/$1"
  printf 'TUNTYPE=%s\nTUNLOCAL=%s\nTUNREMOTE=%s\nTUNTTL=64\nHOST=%s\n' \
         "$2" "$3" "$4" "$6" | _etcnet_opts "$d" iptun static
  echo "$5" > "$d/ipv4address"
  ok "etcnet: туннель $1 ($2) $5  $3->$4"
}

# Включить службу network на следующий ребут, погасить NetworkManager
etcnet_enable() {
  if command -v chkconfig >/dev/null 2>&1; then chkconfig network on 2>/dev/null; fi
  systemctl enable network 2>/dev/null || true
  systemctl disable --now NetworkManager 2>/dev/null || true
  warn "etcnet записан. Сеть службы 'network' активна со следующего ребута."
  warn "Применить сейчас (может оборвать сессию): systemctl restart network"
}
