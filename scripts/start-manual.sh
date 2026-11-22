#!/system/bin/sh
# Manual start helper for non-root Termux after reboot.
# Delegates to the managed no-root watchdog; no root or Android setting changes.
set -u

USER_HOME=${HOME:-/data/data/com.termux/files/home}
HM=${HERMES_HOME:-$USER_HOME/.hermes-home}
VENV=${HERMES_VENV:-$USER_HOME/hermes-venv}
WATCHDOG="$HM/scripts/no-root-watchdog.sh"
ACTION=${1:-start}

if [ "$(id -u 2>/dev/null || true)" = "0" ]; then
  echo "LỖI: start-manual.sh dành cho Termux không root; không chạy dưới UID 0." >&2
  exit 1
fi

case "$ACTION" in
  start|status|stop) ;;
  *) echo "usage: $0 {start|status|stop}" >&2; exit 2 ;;
esac

if [ ! -f "$WATCHDOG" ]; then
  echo "LỖI: không thấy watchdog no-root: $WATCHDOG. Cài lại hermes-android trước." >&2
  exit 1
fi

export HERMES_HOME="$HM"
export HERMES_VENV="$VENV"
exec sh "$WATCHDOG" "$ACTION"
