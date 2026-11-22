#!/system/bin/sh
# =============================================================================
# scripts/start-manual.sh — khởi động Hermes THỦ CÔNG (dùng khi KHÔNG root).
#
# Không có service.d/Magisk → không tự chạy sau reboot. Sau mỗi lần khởi động
# lại máy, chạy tay:
#
#     sh $HERMES_HOME/scripts/start-manual.sh
#
# Script này: nạp env, preflight venv, rồi nohup gateway (và webui nếu có).
# KHÔNG cần root. Idempotent — nếu gateway đang chạy thì bỏ qua.
# =============================================================================
set -u

HM="${HERMES_HOME:-/data/local/hermes-home}"
VENV="${HERMES_VENV:-/data/local/hermes-venv}"

export HOME="$HM"
export HERMES_HOME="$HM"
export PREFIX="${PREFIX:-/data/data/com.termux/files/usr}"
export PATH="$PREFIX/bin:$VENV/bin:/system/bin:/vendor/bin"
export LD_LIBRARY_PATH="$PREFIX/lib:/data/local/node-termux/data/data/com.termux/files/usr/lib"
export LD_PRELOAD="$PREFIX/lib/libpython3.14.so"
export TMPDIR="${TMPDIR:-/data/local/tmp}"
mkdir -p "$TMPDIR" "$HM/logs" 2>/dev/null || true

HERMES_BIN="$VENV/bin/hermes"
[ -x "$HERMES_BIN" ] || HERMES_BIN="$PREFIX/bin/hermes"

if ! command -v "$HERMES_BIN" >/dev/null 2>&1 && [ ! -x "$HERMES_BIN" ]; then
  echo "LỖI: không tìm thấy 'hermes'. Kiểm tra venv $VENV hoặc cài hermes-agent trước."
  exit 1
fi

# Preflight venv nếu có
if [ -f "$HM/scripts/preflight_venv.sh" ]; then
  echo "==> preflight venv..."
  sh "$HM/scripts/preflight_venv.sh" || echo "  (preflight có cảnh báo, vẫn tiếp tục)"
fi

# Gateway: chỉ chạy khi chưa có tiến trình
if pgrep -f "gateway run|gateway restart" >/dev/null 2>&1; then
  echo "==> gateway đã chạy (bỏ qua)."
else
  echo "==> khởi động gateway (nohup)..."
  nohup "$HERMES_BIN" gateway run >> "$TMPDIR/hermes.log" 2>&1 &
  echo "  gateway PID $!"
fi

# Web UI (nếu có) — tuỳ chọn
if [ -f "$HM/web/server.py" ] && [ -x "$HM/scripts/webui.sh" ]; then
  if ! pgrep -f "web/server.py" >/dev/null 2>&1; then
    echo "==> khởi động web UI (port 3000)..."
    sh "$HM/scripts/webui.sh" start || echo "  (bỏ qua webui)"
  fi
fi

echo
echo "Xong. Nhớ: KHÔNG root → KHÔNG tự sống sau reboot. Lần sau cứ chạy lại script này."
echo "Check:  pgrep -f \"gateway run|gateway restart\""
echo "Log:    tail -n 30 $HM/logs/gateway.log"