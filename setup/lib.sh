#!/usr/bin/env bash
# Общие функции для всех setup-скриптов

c_reset='\033[0m'; c_g='\033[1;32m'; c_y='\033[1;33m'; c_r='\033[1;31m'; c_b='\033[1;36m'
log()  { printf "${c_b}[*]${c_reset} %s\n" "$*"; }
ok()   { printf "${c_g}[+]${c_reset} %s\n" "$*"; }
warn() { printf "${c_y}[!]${c_reset} %s\n" "$*"; }
err()  { printf "${c_r}[x]${c_reset} %s\n" "$*" >&2; }

need_root() { [ "$(id -u)" = 0 ] || { err "Запусти от root (sudo)."; exit 1; }; }

# Установка пакетов на Альт (apt-get). Не падаем, если репозиторий недоступен.
pkg() {
  log "Установка пакетов: $*"
  apt-get update -y >/dev/null 2>&1 || warn "apt-get update не прошёл (нет интернета?)"
  apt-get install -y "$@" >/dev/null 2>&1 && ok "Установлено: $*" || warn "Не удалось поставить: $* (возможно уже стоит)"
}

set_hostname() {
  hostnamectl set-hostname "$1" 2>/dev/null || echo "$1" > /etc/hostname
  grep -q "$1" /etc/hosts || echo "127.0.1.1 $1 ${1%%.*}" >> /etc/hosts
  ok "Hostname: $1"
}

set_tz() { timedatectl set-timezone "$TZ_REGION" 2>/dev/null && ok "TZ: $TZ_REGION" || warn "TZ не установлен"; }

enable_forward() {
  sysctl -w net.ipv4.ip_forward=1 >/dev/null
  sed -i '/net.ipv4.ip_forward/d' /etc/sysctl.conf
  echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
  ok "IP forwarding включён"
}

# Создать пользователя с NOPASSWD-sudo (работает на любом дистрибутиве)
make_sudoer() {
  local user="$1" uid="$2" pass="$3"
  if id "$user" >/dev/null 2>&1; then
    warn "$user уже существует"
  else
    if [ -n "$uid" ]; then useradd -m -u "$uid" -s /bin/bash "$user"; else useradd -m -s /bin/bash "$user"; fi
    ok "Создан $user (uid=${uid:-auto})"
  fi
  echo "$user:$pass" | chpasswd
  usermod -aG wheel "$user" 2>/dev/null || true
  echo "$user ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/"$user"
  chmod 440 /etc/sudoers.d/"$user"
  command -v control >/dev/null 2>&1 && control sudo public 2>/dev/null || true
  ok "$user: sudo без пароля"
}

# Префикс -> маска (255.255.255.x)
prefix_to_mask() {
  local p="$1" mask="" i
  for i in 1 2 3 4; do
    if   [ "$p" -ge 8 ]; then mask="${mask}255"; p=$((p-8))
    elif [ "$p" -gt 0 ]; then mask="${mask}$((256 - 2**(8-p) ))"; p=0
    else mask="${mask}0"; fi
    [ "$i" -lt 4 ] && mask="${mask}."
  done
  echo "$mask"
}
# Маска для VLAN200 (используется в dhcpd.conf)
ipcalc_mask() { prefix_to_mask "$VL200_PFX"; }
# Диапазон выдачи для VLAN200: .2 .. (последний-1), .1=шлюз исключён
dhcp_range() {
  local base="${VL200_NET%.*}" last; last=$(( 2**(32-VL200_PFX) - 2 ))
  echo "${base}.2 ${base}.${last}"
}

# Доступ в интернет на внешнем интерфейсе через DHCP
dhcp_up() {
  local ifc="$1"
  ip link set "$ifc" up 2>/dev/null
  (dhcpcd "$ifc" || dhclient "$ifc") >/dev/null 2>&1
  sleep 2
}
