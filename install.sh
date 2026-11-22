#!/system/bin/sh
# =============================================================================
# hermes-android installer — idempotent, tự nhận diện Magisk/Termux.
#
#   curl -sSL https://raw.githubusercontent.com/shiba-108/hermes-android/main/install.sh | bash
#
# An toàn khi chạy lại: mọi file bị thay đều được backup .bak.<timestamp>.
# KHÔNG dùng set -e khi bị pipe | bash (dễ thoát giữa chừng); ta tự set -u.
# =============================================================================
set -u

# ---------------------------------------------------------------------------
# T0. Tìm thư mục repo (local theo dirname, hoặc clone tạm nếu pipe từ curl)
# ---------------------------------------------------------------------------
REPO_DIR="${REPO_DIR:-}"
if [ -n "$REPO_DIR" ] && [ -d "$REPO_DIR" ] && [ -f "$REPO_DIR/install.sh" ]; then
  :
else
  SCRIPT_PATH="$0"
  case "$SCRIPT_PATH" in
    /*) REPO_DIR=$(cd "$(dirname "$SCRIPT_PATH")" 2>/dev/null && pwd) ;;
    *)  REPO_DIR="" ;;
  esac
fi

if [ -z "$REPO_DIR" ] || [ ! -f "$REPO_DIR/install.sh" ] || [ ! -d "$REPO_DIR/service.d" ]; then
  echo "==> Không thấy repo local, tải tạm về /data/local/tmp ..."
  TMPREPO=/data/local/tmp/hermes-android-install
  rm -rf "$TMPREPO"
  mkdir -p /data/local/tmp 2>/dev/null || true
  if command -v git >/dev/null 2>&1; then
    git clone --depth 1 https://github.com/shiba-108/hermes-android.git "$TMPREPO" || {
      echo "LỖI: git clone thất bại. Kiểm tra mạng."; exit 1; }
  else
    echo "LỖI: không có git để clone. Cài git trước."; exit 1
  fi
  REPO_DIR="$TMPREPO"
fi
echo "==> Repo: $REPO_DIR"

# ---------------------------------------------------------------------------
# T1. Xác định môi trường
# ---------------------------------------------------------------------------
HM="${HERMES_HOME:-/data/local/hermes-home}"
SD=/data/adb/service.d
TS=$(date +%Y%m%d-%H%M%S)
IS_MAGISK=0
IS_ROOT=0
[ "$(id -u 2>/dev/null)" = "0" ] && IS_ROOT=1
if [ -d /data/adb/magisk ] || [ -d /data/adb/modules ] || command -v magisk >/dev/null 2>&1; then
  IS_MAGISK=1
fi
echo "==> HERMES_HOME=$HM | root=$IS_ROOT | magisk=$IS_MAGISK"

mkdir -p "$HM/scripts" "$HM/backups" "$HM/logs" 2>/dev/null || true
if [ "$IS_ROOT" = "1" ] && [ "$IS_MAGISK" = "1" ]; then
  mkdir -p "$SD" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# T2. service.d (chỉ khi có root + Magisk)
# ---------------------------------------------------------------------------
if [ -d "$REPO_DIR/service.d" ] && [ "$IS_ROOT" = "1" ] && [ "$IS_MAGISK" = "1" ]; then
  echo "==> service.d -> $SD"
  for f in "$REPO_DIR"/service.d/*.sh; do
    [ -e "$f" ] || continue
    b=$(basename "$f")
    if [ -f "$SD/$b" ]; then
      cp -a "$SD/$b" "$SD/$b.bak.$TS"
      echo "  backup $b -> $b.bak.$TS"
    fi
    cp -a "$f" "$SD/$b"
    chmod 755 "$SD/$b"
    sh -n "$SD/$b" 2>/dev/null || echo "  CẢNH BÁO: cú pháp $b có lỗi (sh -n)"
    echo "  install $SD/$b"
  done
else
  echo "==> Bỏ qua service.d (cần root + Magisk). Termux thuần dùng nohup/watchdog thủ công."
fi

# ---------------------------------------------------------------------------
# T3. scripts -> $HM/scripts
# ---------------------------------------------------------------------------
if [ -d "$REPO_DIR/scripts" ]; then
  echo "==> scripts -> $HM/scripts"
  for f in "$REPO_DIR"/scripts/*; do
    [ -e "$f" ] || continue
    b=$(basename "$f")
    if [ -f "$HM/scripts/$b" ]; then
      cp -a "$HM/scripts/$b" "$HM/scripts/$b.bak.$TS"
      echo "  backup $b"
    fi
    cp -a "$f" "$HM/scripts/$b"
    chmod 755 "$HM/scripts/$b"
    echo "  install $HM/scripts/$b"
  done
fi

# ---------------------------------------------------------------------------
# T4. locks -> $HM/backups (chỉ cài khi chưa có, tránh đè lock đang chạy)
# ---------------------------------------------------------------------------
if [ -d "$REPO_DIR/locks" ]; then
  echo "==> locks -> $HM/backups"
  for f in "$REPO_DIR"/locks/*; do
    [ -e "$f" ] || continue
    b=$(basename "$f")
    if [ ! -f "$HM/backups/$b" ]; then
      cp -a "$f" "$HM/backups/$b"
      echo "  install $HM/backups/$b"
    else
      echo "  giữ nguyên $HM/backups/$b"
    fi
  done
fi

# ---------------------------------------------------------------------------
# T5. skills -> $HM/skills (chỉ cài khi chưa có)
# ---------------------------------------------------------------------------
if [ -d "$REPO_DIR/skills" ]; then
  echo "==> skills -> $HM/skills"
  for d in "$REPO_DIR"/skills/*/; do
    [ -d "$d" ] || continue
    n=$(basename "$d")
    if [ ! -f "$HM/skills/$n/SKILL.md" ]; then
      mkdir -p "$HM/skills/$n"
      cp -a "$d/SKILL.md" "$HM/skills/$n/SKILL.md"
      echo "  install skills/$n"
    else
      echo "  giữ nguyên skills/$n"
    fi
  done
fi

# ---------------------------------------------------------------------------
# T6. web/ -> $HM/web (nếu có)
# ---------------------------------------------------------------------------
if [ -d "$REPO_DIR/web" ]; then
  echo "==> web -> $HM/web"
  mkdir -p "$HM/web" 2>/dev/null || true
  cp -a "$REPO_DIR"/web/. "$HM/web/" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# T7. venv + hermes-agent
# ---------------------------------------------------------------------------
VENV="${HERMES_VENV:-/data/local/hermes-venv}"
AGENT="${HERMES_AGENT_DIR:-/data/local/hermes-agent}"

if [ ! -d "$AGENT" ]; then
  echo "==> hermes-agent chưa có -> clone"
  if command -v git >/dev/null 2>&1; then
    git clone --depth 1 https://github.com/NousResearch/hermes-agent.git "$AGENT" || \
      echo "  CẢNH BÁO: clone hermes-agent thất bại, bỏ qua."
  else
    echo "  CẢNH BÁO: không có git, bỏ qua clone hermes-agent."
  fi
fi

LOCK="$HM/backups/venv-requirements.android.lock"
[ -f "$LOCK" ] || LOCK="$HM/backups/venv-requirements.lock"

if [ -d "$AGENT" ] && command -v python >/dev/null 2>&1; then
  if [ ! -x "$VENV/bin/python" ]; then
    echo "==> tạo venv $VENV"
    python -m venv "$VENV" 2>/dev/null || echo "  CẢNH BÁO: tạo venv thất bại."
  fi
  if [ -x "$VENV/bin/python" ]; then
    echo "==> pip install từ lock: $LOCK"
    "$VENV/bin/python" -m pip install --upgrade pip >>"$HM/logs/install-pip.log" 2>&1 || true
    "$VENV/bin/python" -m pip install -r "$LOCK" >>"$HM/logs/install-pip.log" 2>&1 && \
      echo "  venv OK" || echo "  CẢNH BÁO: pip install lỗi, xem $HM/logs/install-pip.log"
  fi
else
  echo "==> Bỏ qua tạo venv (thiếu hermes-agent hoặc python)."
fi

# ---------------------------------------------------------------------------
# T8. Tổng kết
# ---------------------------------------------------------------------------
echo
echo "============================================================"
echo " Xong."
echo "   HERMES_HOME : $HM"
echo "   venv        : $VENV"
echo "   agent dir   : $AGENT"
[ "$IS_MAGISK" = "1" ] && [ "$IS_ROOT" = "1" ] && echo " service.d  : $SD (có hiệu lực sau reboot)"
echo
echo " Bước tiếp theo:"
echo "   1) Khai báo secret trong $HM/.env"
echo "        OPENROUTER_API_KEY=..."
echo "        TELEGRAM_BOT_TOKEN=..."
echo "   2) Đặt model free:"
echo "        hermes config set model.default baidu/ernie-5.5-flash-preview:free"
echo "        hermes config set model.provider openrouter"
echo "   3) Reboot máy (nạp service.d) rồi mở Telegram nhắn cho bot."
echo "============================================================"