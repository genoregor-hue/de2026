#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  Демоэкзамен 2026 · Модуль 1 · АВТО-УСТАНОВЩИК
#  Сам определяет роль машины по hostname и запускает нужный setup.
#  Запуск:  sudo ./bootstrap.sh           (по hostname)
#           sudo ./bootstrap.sh hq-rtr    (вручную указать роль)
# ════════════════════════════════════════════════════════════════════
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
. "$DIR/setup/lib.sh"
need_root

ROLE="${1:-}"
if [ -z "$ROLE" ]; then
  H="$(hostname -s 2>/dev/null || hostname)"; H="$(echo "$H" | tr 'A-Z' 'a-z')"
  case "$H" in
    isp)     ROLE=isp ;;
    hq-rtr)  ROLE=hq-rtr ;;
    br-rtr)  ROLE=br-rtr ;;
    hq-srv)  ROLE=hq-srv ;;
    br-srv)  ROLE=br-srv ;;
    hq-cli)  ROLE=hq-cli ;;
    *)       ROLE="" ;;
  esac
fi

if [ -z "$ROLE" ]; then
  warn "Роль не определена по hostname ('$(hostname)')."
  echo "Укажи вручную одну из: isp hq-rtr br-rtr hq-srv br-srv hq-cli"
  echo "Пример: sudo ./bootstrap.sh hq-srv"
  exit 1
fi

SCRIPT="$DIR/setup/$ROLE.sh"
[ -f "$SCRIPT" ] || { err "Нет скрипта для роли '$ROLE'"; exit 1; }

log "Роль: $ROLE  →  $SCRIPT"
echo "ВНИМАНИЕ: проверь имена интерфейсов в config.env (ip -br link), потом Enter."
read -r _
chmod +x "$SCRIPT"
exec bash "$SCRIPT"
