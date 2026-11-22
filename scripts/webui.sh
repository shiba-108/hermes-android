#!/system/bin/sh
# =============================================================================
# scripts/webui.sh — start/stop/status web UI.
# Root default preserves existing 0.0.0.0 behavior. No-root defaults to
# loopback because the UI has no authentication. Remote binding must be explicit.
# PID files are advisory: signal only a live process whose cmdline matches WEB.
# =============================================================================
set -u

IS_ROOT=0
[ "$(id -u 2>/dev/null || true)" = "0" ] && IS_ROOT=1
if [ -n "${HERMES_HOME:-}" ]; then
  HM=$HERMES_HOME
elif [ "$IS_ROOT" = "1" ]; then
  HM=/data/local/hermes-home
else
  HM="${HOME:-/data/data/com.termux/files/home}/.hermes-home"
fi
WEB="$HM/web/server.py"
if [ -n "${HERMES_VENV:-}" ]; then
  VENV=$HERMES_VENV
elif [ "$IS_ROOT" = "1" ]; then
  VENV=/data/local/hermes-venv
else
  VENV="${HOME:-/data/data/com.termux/files/home}/hermes-venv"
fi
PORT="${WEBUI_PORT:-3000}"
if [ -n "${WEBUI_HOST:-}" ]; then
  HOST=$WEBUI_HOST
elif [ "$IS_ROOT" = "1" ]; then
  HOST=0.0.0.0
else
  HOST=127.0.0.1
fi
LOG="$HM/logs/webui.log"
PIDFILE="$HM/webui.pid"
PY="$VENV/bin/python"
[ -x "$PY" ] || PY=python3

valid_pid() {
  case "${1:-}" in ''|*[!0-9]*) return 1 ;; esac
  [ "$1" -gt 1 ] 2>/dev/null
}

# Return 0=verified server, 1=dead/stale/mismatch, 2=alive but identity unreadable.
webui_state() {
  [ -r "$PIDFILE" ] || return 1
  pid=$(cat "$PIDFILE" 2>/dev/null)
  valid_pid "$pid" || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  if cmdline=$(tr '\000' ' ' < "/proc/$pid/cmdline" 2>/dev/null); then
    [ -n "$cmdline" ] || return 2
  else
    return 2
  fi
  case "$cmdline" in *"$WEB"*) return 0 ;; *) return 1 ;; esac
}

start() {
  webui_state
  state=$?
  case "$state" in
    0) echo "webui đang chạy (PID $(cat "$PIDFILE"))"; return 0 ;;
    2) echo "LỖI: PID webui còn sống nhưng không xác minh được; không khởi chạy trùng." >&2; return 1 ;;
    1) rm -f "$PIDFILE" ;;
  esac
  if [ ! -f "$WEB" ]; then
    echo "LỖI: không thấy $WEB"; return 1
  fi
  mkdir -p "$HM/logs"
  HERMES_HOME="$HM" HERMES_VENV="$VENV" nohup "$PY" "$WEB" --host "$HOST" --port "$PORT" \
    >> "$LOG" 2>&1 </dev/null &
  pid=$!
  echo "$pid" > "$PIDFILE"
  sleep 1
  webui_state
  state=$?
  case "$state" in
    0) echo "đã start webui PID $pid trên $HOST:$PORT" ;;
    2) echo "Web UI đã được gọi nhưng không xác minh được cmdline; giữ PID file, không gửi tín hiệu." >&2; return 1 ;;
    *) rm -f "$PIDFILE"; echo "LỖI: webui không khởi động, xem $LOG"; return 1 ;;
  esac
}

stop() {
  webui_state
  state=$?
  case "$state" in
    0)
      pid=$(cat "$PIDFILE" 2>/dev/null)
      if kill "$pid" 2>/dev/null; then
        rm -f "$PIDFILE"
        echo "đã dừng webui PID $pid"
      else
        echo "LỖI: không gửi được TERM; giữ PID file." >&2
        return 1
      fi
      ;;
    2) echo "LỖI: PID còn sống nhưng không xác minh được; không gửi TERM và giữ PID file." >&2; return 1 ;;
    1) rm -f "$PIDFILE"; echo "webui không chạy hoặc PID file đã cũ" ;;
  esac
}

status() {
  webui_state
  state=$?
  case "$state" in
    0)
      echo "webui RUNNING PID $(cat "$PIDFILE") host $HOST port $PORT"
      tail -n 3 "$LOG" 2>/dev/null
      ;;
    2) echo "webui ALIVE but identity UNVERIFIED; no signal will be sent"; exit 1 ;;
    *) echo "webui STOPPED"; exit 1 ;;
  esac
}

case "${1:-start}" in
  start) start ;;
  stop) stop ;;
  restart) stop; sleep 1; start ;;
  status) status ;;
  *) echo "usage: $0 {start|stop|restart|status}"; exit 2 ;;
esac
