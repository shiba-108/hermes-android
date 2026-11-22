#!/system/bin/sh
# Termux-only watchdog. Does not call Shizuku, pm, deviceidle, iptables, or alter DNS.
set -u

USER_HOME=${HOME:-/data/data/com.termux/files/home}
HM=${HERMES_HOME:-$USER_HOME/.hermes-home}
VENV=${HERMES_VENV:-$USER_HOME/hermes-venv}
PREFIX=${PREFIX:-/data/data/com.termux/files/usr}
HERMES_BIN=${HERMES_BIN:-$VENV/bin/hermes}
PIDFILE="$HM/no-root-watchdog.pid"
GATEWAY_PIDFILE="$HM/gateway.pid"
LOG="$HM/logs/no-root-watchdog.log"
GATEWAY_LOG="$HM/logs/gateway.log"
INTERVAL=${HERMES_WATCHDOG_INTERVAL:-300}
case "$INTERVAL" in ''|*[!0-9]*) INTERVAL=300 ;; esac
[ "$INTERVAL" -ge 10 ] 2>/dev/null || INTERVAL=300

case "$0" in
  /*) SCRIPT_PATH=$0 ;;
  *) SCRIPT_PATH=$(cd "$(dirname "$0")" 2>/dev/null && pwd)/$(basename "$0") ;;
esac

export HOME="$USER_HOME"
export HERMES_HOME="$HM"
export HERMES_VENV="$VENV"
export PREFIX
export TMPDIR=${TMPDIR:-$PREFIX/tmp}
export PATH="$VENV/bin:$PREFIX/bin:/system/bin:/vendor/bin:${PATH:-}"

log() {
  mkdir -p "$HM/logs" 2>/dev/null || return 1
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date)" "$*" >> "$LOG"
}

valid_pid() {
  case "${1:-}" in ''|*[!0-9]*) return 1 ;; esac
  [ "$1" -gt 1 ] 2>/dev/null
}

# Return 0=verified managed process, 1=dead/stale/mismatch, 2=alive but identity unreadable.
process_state() {
  pidfile=$1
  pattern=$2
  [ -r "$pidfile" ] || return 1
  pid=$(cat "$pidfile" 2>/dev/null)
  valid_pid "$pid" || return 1
  kill -0 "$pid" 2>/dev/null || return 1
  if cmdline=$(tr '\000' ' ' < "/proc/$pid/cmdline" 2>/dev/null); then
    [ -n "$cmdline" ] || return 2
  else
    return 2
  fi
  case "$cmdline" in *"$pattern"*) return 0 ;; *) return 1 ;; esac
}

stop_managed_gateway() {
  process_state "$GATEWAY_PIDFILE" "$HERMES_BIN gateway run"
  state=$?
  case "$state" in
    0)
      pid=$(cat "$GATEWAY_PIDFILE" 2>/dev/null)
      if kill "$pid" 2>/dev/null; then
        log "sent TERM to verified managed gateway pid=$pid"
        rm -f "$GATEWAY_PIDFILE"
      else
        log "failed to signal verified gateway pid=$pid; keeping PID file"
      fi
      ;;
    1) rm -f "$GATEWAY_PIDFILE" ;;
    2) log "gateway PID exists but cmdline is unreadable; refusing to signal or forget pid" ;;
  esac
}

start_gateway_if_needed() {
  process_state "$GATEWAY_PIDFILE" "$HERMES_BIN gateway run"
  state=$?
  case "$state" in
    0) return 0 ;;
    2) log "gateway PID exists but cmdline is unreadable; refusing to start a duplicate"; return 1 ;;
    1) rm -f "$GATEWAY_PIDFILE" ;;
  esac
  if [ ! -x "$HERMES_BIN" ]; then
    log "Hermes binary not found/executable: $HERMES_BIN"
    return 1
  fi
  log "starting Hermes gateway"
  nohup "$HERMES_BIN" gateway run >> "$GATEWAY_LOG" 2>&1 </dev/null &
  pid=$!
  case "$pid" in ''|*[!0-9]*) log "could not capture gateway PID"; return 1 ;; esac
  printf '%s\n' "$pid" > "$GATEWAY_PIDFILE" || return 1
  sleep 2
  process_state "$GATEWAY_PIDFILE" "$HERMES_BIN gateway run"
  state=$?
  case "$state" in
    0) log "gateway started and verified pid=$pid"; return 0 ;;
    2) log "gateway started but cmdline is unreadable; keeping PID file and not signaling"; return 1 ;;
    *) rm -f "$GATEWAY_PIDFILE"; log "gateway exited or identity mismatched during startup; see $GATEWAY_LOG"; return 1 ;;
  esac
}

run_loop() {
  mkdir -p "$HM/logs" || exit 1
  printf '%s\n' "$$" > "$PIDFILE" || exit 1
  trap 'log "watchdog stopping"; stop_managed_gateway; if [ "$(cat "$PIDFILE" 2>/dev/null)" = "$$" ]; then rm -f "$PIDFILE"; fi; exit 0' INT TERM HUP
  log "watchdog started interval=${INTERVAL}s"
  while :; do
    start_gateway_if_needed || true
    elapsed=0
    while [ "$elapsed" -lt "$INTERVAL" ]; do
      sleep 10
      elapsed=$((elapsed + 10))
      [ -f "$PIDFILE" ] || { log "watchdog pid file removed; exiting"; stop_managed_gateway; exit 0; }
    done
  done
}

case "${1:-status}" in
  start)
    mkdir -p "$HM/logs" || { echo "LỖI: không thể tạo $HM/logs" >&2; exit 1; }
    process_state "$PIDFILE" 'no-root-watchdog.sh run'
    state=$?
    case "$state" in
      0) echo "no-root watchdog đang chạy (PID $(cat "$PIDFILE"))"; exit 0 ;;
      2) echo "LỖI: PID watchdog còn sống nhưng không đọc được danh tính; không khởi chạy trùng." >&2; exit 1 ;;
      1) rm -f "$PIDFILE" ;;
    esac
    if [ ! -x "$HERMES_BIN" ]; then
      echo "LỖI: không thấy Hermes executable: $HERMES_BIN" >&2
      echo "Kiểm tra cài đặt venv; có thể đặt HERMES_VENV/HERMES_BIN." >&2
      exit 1
    fi
    nohup sh "$SCRIPT_PATH" run >> "$LOG" 2>&1 </dev/null &
    echo "Đã yêu cầu khởi chạy watchdog; log: $LOG"
    ;;
  run)
    run_loop
    ;;
  stop)
    process_state "$PIDFILE" 'no-root-watchdog.sh run'
    state=$?
    case "$state" in
      0)
        pid=$(cat "$PIDFILE" 2>/dev/null)
        if kill "$pid" 2>/dev/null; then echo "Đã gửi TERM tới watchdog PID $pid."; else echo "Không gửi được TERM; giữ PID file." >&2; fi
        ;;
      2) echo "Watchdog PID còn sống nhưng không xác minh được; không gửi TERM và giữ PID file." >&2 ;;
      1) rm -f "$PIDFILE"; echo "Watchdog không chạy hoặc PID file đã cũ." ;;
    esac
    stop_managed_gateway
    ;;
  status)
    process_state "$PIDFILE" 'no-root-watchdog.sh run'
    state=$?
    case "$state" in
      0) echo "no-root watchdog RUNNING PID $(cat "$PIDFILE")" ;;
      2) echo "no-root watchdog ALIVE but identity UNVERIFIED; no signal will be sent" ;;
      *) echo "no-root watchdog STOPPED" ;;
    esac
    process_state "$GATEWAY_PIDFILE" "$HERMES_BIN gateway run"
    state=$?
    case "$state" in
      0) echo "Hermes gateway RUNNING PID $(cat "$GATEWAY_PIDFILE")" ;;
      2) echo "Hermes gateway ALIVE but identity UNVERIFIED; no signal will be sent" ;;
      *) echo "Hermes gateway STOPPED" ;;
    esac
    ;;
  *)
    echo "usage: $0 {start|run|stop|status}" >&2
    exit 2
    ;;
esac
