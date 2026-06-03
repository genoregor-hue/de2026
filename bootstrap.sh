#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════
#  Демоэкзамен 2026 · Модуль 1 · АВТО-УСТАНОВЩИК
#  Определяет роль машины по hostname и запускает нужный setup-скрипт.
#  Запуск:  sudo ./bootstrap.sh           # по hostname
#           sudo ./bootstrap.sh hq-rtr    # вручную указать роль
#           sudo TZ_REGION=Asia/Novosibirsk ./bootstrap.sh   # сменить TZ
# ════════════════════════════════════════════════════════════════════
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
[ "$(id -u)" = 0 ] || { echo "[x] Запусти от root (sudo)."; exit 1; }

ROLE="${1:-}"
if [ -z "$ROLE" ]; then
  H="$(hostname -s 2>/dev/null || hostname)"; H="$(echo "$H" | tr 'A-Z' 'a-z')"
  case "$H" in
    isp)    ROLE=isp ;;
    hq-rtr) ROLE=hq-rtr ;;
    br-rtr) ROLE=br-rtr ;;
    hq-srv) ROLE=hq-srv ;;
    br-srv) ROLE=br-srv ;;
    hq-cli) ROLE=hq-cli ;;
    *)      ROLE="" ;;
  esac
fi

if [ -z "$ROLE" ]; then
  echo "[!] Роль не определена по hostname ('$(hostname)')."
  echo "    Укажи вручную: isp | hq-rtr | br-rtr | hq-srv | br-srv | hq-cli"
  echo "    Пример: sudo ./bootstrap.sh hq-srv"
  exit 1
fi

SCRIPT="$DIR/setup/$ROLE.sh"
[ -f "$SCRIPT" ] || { echo "[x] Нет скрипта для роли '$ROLE'"; exit 1; }

echo "[*] Роль: $ROLE  ->  $SCRIPT"
echo "[*] TZ_REGION=${TZ_REGION:-Europe/Moscow}"
echo "[!] Проверь имена интерфейсов в setup/$ROLE.sh (по умолчанию ens19/ens20/ens21)."
echo "    Если на стенде другие - поправь перед запуском. Enter для старта."
read -r _
chmod +x "$SCRIPT"
exec bash "$SCRIPT"
