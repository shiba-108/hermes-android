#!/system/bin/sh
# =============================================================================
# scripts/webui.sh — khởi động / dừng / status web UI (port 3000, nohup).
# KHÔNG dùng tmux. Được watchdog (05-watchdog.sh) canh sống.
# =============================================================================
set -u

HM="${HERMES_HOME:-/data/local/hermes-home}"
WEB="$HM/web/server.py"
VENV="${HERMES_VENV:-/data/local/hermes-venv}"
PORT="${WEBUI_PORT:-3000}"
LOG="$HM/logs/webui.log"
PIDFILE="$HM/webui.pid"
PY="$VENV/bin/python"
[ -x "$PY" ] || PY=python3

is_running() {
  [ -f "$PIDFILE" ] || return 1
  pid=$(cat "$PIDFILE" 2>/dev/null)
  [ -n "$pid" ] || return 1
  kill -0 "$pid" 2>/dev/null
}

start() {
  if is_running; then
    echo "webui đang chạy (PID $(cat "$PIDFILE"))"
    return 0
  fi
  if [ ! -f "$WEB" ]; then
    echo "LỖI: không thấy $WEB"; return 1
  fi
  mkdir -p "$HM/logs"
  HERMES_HOME="$HM" nohup "$PY" "$WEB" --port "$PORT" \
    >> "$LOG" 2>&1 &
  echo $! > "$PIDFILE"
  sleep 1
  if is_running; then
    echo "đã start webui PID $(cat "$PIDFILE") trên cổng $PORT"
  else
    echo "LỖI: webui không khởi động, xem $LOG"
    return 1
  fi
}

stop() {
  if is_running; then
    pid=$(cat "$PIDFILE")
    kill "$pid" 2>/dev/null && echo "đã dừng webui PID $pid"
    rm -f "$PIDFILE"
  else
    echo "webui không chạy"
  fi
}

status() {
  if is_running; then
    echo "webui RUNNING PID $(cat "$PIDFILE") port $PORT"
    tail -n 3 "$LOG" 2>/dev/null
  else
    echo "webui STOPPED"
    exit 1
  fi
}

case "${1:-start}" in
  start) start ;;
  stop) stop ;;
  restart) stop; sleep 1; start ;;
  status) status ;;
  *) echo "usage: $0 {start|stop|restart|status}"; exit 2 ;;
esac