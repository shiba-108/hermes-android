#!/system/bin/sh
# =============================================================================
# hermes-android installer v2 — auto-detect root/Magisk vs Termux no-root.
#
#   curl -sSL https://raw.githubusercontent.com/shiba-108/hermes-android/main/install.sh | bash
#
# Root + Magisk keeps the existing service.d flow. No-root installs into the
# Termux user's home and never changes Android system settings or boot startup.
# =============================================================================
set -u

# ---------------------------------------------------------------------------
# T0. Detect privilege and locate repo (local path or temporary clone for pipe).
# ---------------------------------------------------------------------------
IS_ROOT=0
IS_MAGISK=0
[ "$(id -u 2>/dev/null || true)" = "0" ] && IS_ROOT=1
if [ -d /data/adb/magisk ] || [ -d /data/adb/modules ] || command -v magisk >/dev/null 2>&1; then
  IS_MAGISK=1
fi
if [ "$IS_ROOT" = "1" ]; then MODE=root; else MODE=no-root; fi

USER_HOME=${HOME:-/data/local/tmp}
if [ "$MODE" = "root" ]; then
  DEFAULT_HM=/data/local/hermes-home
else
  DEFAULT_HM="$USER_HOME/.hermes-home"
fi
HM="${HERMES_HOME:-$DEFAULT_HM}"
PYTHON=$(command -v python 2>/dev/null || command -v python3 2>/dev/null || true)
if [ -z "$PYTHON" ]; then
  echo "LỖI: không tìm thấy Python (python/python3); cần Python để tạo hoặc cập nhật venv." >&2
  exit 1
fi

REPO_DIR="${REPO_DIR:-}"
if [ -n "$REPO_DIR" ] && [ -d "$REPO_DIR" ] && [ -f "$REPO_DIR/install.sh" ]; then
  :
else
  SCRIPT_DIR=
  case "$0" in
    /*) SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd) ;;
    */*) SCRIPT_DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd) ;;
    *) [ -f ./install.sh ] && SCRIPT_DIR=$(pwd) ;;
  esac
  if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/install.sh" ] && [ -d "$SCRIPT_DIR/service.d" ]; then
    REPO_DIR=$SCRIPT_DIR
  else
    TMPBASE=${TMPDIR:-}
    if [ -z "$TMPBASE" ] || [ ! -d "$TMPBASE" ] || [ ! -w "$TMPBASE" ]; then
      TMPBASE="$USER_HOME/.cache"
    fi
    mkdir -p "$TMPBASE" 2>/dev/null || {
      echo "LỖI: không tạo được thư mục tạm trong $TMPBASE"; exit 1; }
    TMPREPO="$TMPBASE/hermes-android-install-$$"
    echo "==> Không thấy repo local, clone tạm vào $TMPREPO ..."
    if command -v git >/dev/null 2>&1; then
      git clone --depth 1 https://github.com/shiba-108/hermes-android.git "$TMPREPO" || {
        echo "LỖI: git clone thất bại. Kiểm tra mạng và cài git trong Termux."; exit 1; }
    else
      echo "LỖI: không có git để clone. Cài git trong Termux trước."; exit 1
    fi
    REPO_DIR=$TMPREPO
  fi
fi
if [ ! -f "$REPO_DIR/install.sh" ] || [ ! -d "$REPO_DIR/service.d" ]; then
  echo "LỖI: repo không đầy đủ: $REPO_DIR"; exit 1
fi

if [ "$MODE" = "root" ]; then
  VENV_DEFAULT=/data/local/hermes-venv
  AGENT_DEFAULT=/data/local/hermes-agent
else
  VENV_DEFAULT="$USER_HOME/hermes-venv"
  AGENT_DEFAULT="$USER_HOME/hermes-agent"
fi
VENV="${HERMES_VENV:-$VENV_DEFAULT}"
AGENT="${HERMES_AGENT_DIR:-$AGENT_DEFAULT}"
if [ ! -d "$AGENT" ] && ! command -v git >/dev/null 2>&1; then
  echo "LỖI: cần git để clone hermes-agent vào $AGENT nhưng không tìm thấy git." >&2
  echo "Cài git rồi chạy lại installer." >&2
  exit 1
fi

echo "==> Repo: $REPO_DIR"
echo "==> Chế độ: $MODE | root=$IS_ROOT | magisk=$IS_MAGISK"
echo "==> HERMES_HOME=$HM"

# ---------------------------------------------------------------------------
# T1. Writable application directories. No-root stays inside Termux HOME.
# ---------------------------------------------------------------------------
SD=/data/adb/service.d
TS=$(date +%Y%m%d-%H%M%S)
mkdir -p "$HM/scripts" "$HM/backups" "$HM/logs" 2>/dev/null || {
  echo "LỖI: không tạo được thư mục trong $HM"; exit 1; }
if [ "$IS_ROOT" = "1" ] && [ "$IS_MAGISK" = "1" ]; then
  mkdir -p "$SD" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# T2. service.d (root + Magisk only; original root flow retained).
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
  echo "==> Bỏ qua service.d (chỉ dùng khi có root + Magisk)."
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
# T4. locks -> $HM/backups (install only if absent).
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
# T5. skills -> $HM/skills (install only if absent).
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
# T6. web/ -> $HM/web (if present).
# ---------------------------------------------------------------------------
if [ -d "$REPO_DIR/web" ]; then
  echo "==> web -> $HM/web"
  mkdir -p "$HM/web" 2>/dev/null || true
  cp -a "$REPO_DIR"/web/. "$HM/web/" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# T7. venv + hermes-agent.
# ---------------------------------------------------------------------------
if [ ! -d "$AGENT" ]; then
  echo "==> hermes-agent chưa có -> clone vào $AGENT"
  if command -v git >/dev/null 2>&1; then
    git clone --depth 1 https://github.com/NousResearch/hermes-agent.git "$AGENT" || {
      echo "LỖI: git clone hermes-agent thất bại; installer chưa hoàn tất." >&2
      exit 1
    }
  else
    echo "LỖI: cần git để clone hermes-agent nhưng không tìm thấy git." >&2
    exit 1
  fi
fi

LOCK="$HM/backups/venv-requirements.android.lock"
[ -f "$LOCK" ] || LOCK="$HM/backups/venv-requirements.lock"

if [ -d "$AGENT" ] && [ -n "$PYTHON" ]; then
  if [ ! -x "$VENV/bin/python" ]; then
    echo "==> tạo venv $VENV"
    "$PYTHON" -m venv "$VENV" 2>/dev/null || echo "  CẢNH BÁO: tạo venv thất bại."
  fi
  if [ -x "$VENV/bin/python" ]; then
    echo "==> pip install từ lock: $LOCK"
    "$VENV/bin/python" -m pip install --upgrade pip >>"$HM/logs/install-pip.log" 2>&1 || true
    if "$VENV/bin/python" -m pip install -r "$LOCK" >>"$HM/logs/install-pip.log" 2>&1; then
      if [ "$MODE" = "no-root" ]; then
        # The Android lock pins runtime dependencies separately; install only the
        # Hermes package metadata/entry point here, without silently re-resolving deps.
        "$VENV/bin/python" -m pip install --no-deps -e "$AGENT" >>"$HM/logs/install-pip.log" 2>&1 && \
          echo "  hermes-agent entry point OK" || echo "  CẢNH BÁO: cài hermes-agent lỗi, xem $HM/logs/install-pip.log"
      fi
      echo "  venv OK"
    else
      echo "  CẢNH BÁO: pip install lỗi, xem $HM/logs/install-pip.log"
    fi
  fi
else
  echo "==> Bỏ qua tạo venv (thiếu hermes-agent hoặc Python)."
fi

# ---------------------------------------------------------------------------
# T8. Summary
# ---------------------------------------------------------------------------
echo
echo "============================================================"
echo " Xong."
echo "   HERMES_HOME : $HM"
echo "   venv        : $VENV"
echo "   agent dir   : $AGENT"
if [ "$IS_MAGISK" = "1" ] && [ "$IS_ROOT" = "1" ]; then
  echo " service.d    : $SD (có hiệu lực sau reboot)"
fi
echo
echo " Bước tiếp theo:"
echo "   1) Khai báo secret trong $HM/.env (không lưu trong repo)."
echo "        OPENROUTER_API_KEY=..."
echo "        TELEGRAM_BOT_TOKEN=..."
echo "   2) Đặt model free bằng hermes config set như hướng dẫn README."
if [ "$MODE" = "no-root" ]; then
  echo "   3) Khởi chạy thủ công: sh $HM/scripts/no-root-watchdog.sh start"
  echo "      Tùy chọn tự chạy sau reboot: cài/mở Termux:Boot, rồi chạy:"
  echo "      sh $HM/scripts/termux-boot.sh install"
  echo "   4) Shizuku và Private DNS là tùy chọn; installer không đổi quyền/cài đặt hệ thống."
else
  echo "   3) Reboot máy (nạp service.d nếu có Magisk), rồi mở Telegram nhắn cho bot."
fi
echo "============================================================"
