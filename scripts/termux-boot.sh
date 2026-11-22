#!/system/bin/sh
# Install this script into Termux:Boot only after an explicit `install` command.
# User paths are stored as data, never interpolated into executable shell source.
set -u

USER_HOME=${HOME:-/data/data/com.termux/files/home}
HM=${HERMES_HOME:-$USER_HOME/.hermes-home}
VENV=${HERMES_VENV:-$USER_HOME/hermes-venv}
BOOT_DIR="$USER_HOME/.termux/boot"
BOOT_FILE="$BOOT_DIR/hermes-start.sh"
CONFIG_FILE="$BOOT_DIR/hermes-start.conf"
BOOT_MARKER='# HERMES_TERMUX_BOOT_MANAGED=1'
CONFIG_MARKER='# HERMES_TERMUX_BOOT_CONFIG_MANAGED=1'

case "$0" in
  /*) SOURCE_PATH=$0 ;;
  *) SOURCE_PATH=$(cd "$(dirname "$0")" 2>/dev/null && pwd)/$(basename "$0") ;;
esac

is_managed_file() {
  file=$1
  marker=$2
  [ -f "$file" ] && {
    [ "$(sed -n '1p' "$file" 2>/dev/null)" = "$marker" ] ||
      [ "$(sed -n '2p' "$file" 2>/dev/null)" = "$marker" ]
  }
}

install_boot() {
  [ -f "$SOURCE_PATH" ] || { echo "LỖI: không thấy script nguồn $SOURCE_PATH" >&2; exit 1; }
  [ -n "$HM" ] && [ -n "$VENV" ] || { echo "LỖI: HERMES_HOME/HERMES_VENV không được rỗng." >&2; exit 1; }
  newline='
'
  case "$HM$VENV" in *"$newline"*) echo "LỖI: đường dẫn có newline, không thể lưu cấu hình an toàn." >&2; exit 1 ;; esac
  mkdir -p "$BOOT_DIR" || { echo "LỖI: không tạo được $BOOT_DIR" >&2; exit 1; }

  if [ -e "$BOOT_FILE" ]; then
    if is_managed_file "$BOOT_FILE" "$BOOT_MARKER"; then
      if is_managed_file "$CONFIG_FILE" "$CONFIG_MARKER"; then
        echo "Termux:Boot hook đã được cài: $BOOT_FILE"
        exit 0
      fi
      echo "LỖI: hook được quản lý nhưng thiếu/không hợp lệ file cấu hình; không ghi đè." >&2
      exit 1
    fi
    echo "LỖI: $BOOT_FILE đã tồn tại nhưng không do hermes-android quản lý; không ghi đè." >&2
    exit 1
  fi
  if [ -e "$CONFIG_FILE" ]; then
    echo "LỖI: $CONFIG_FILE đã tồn tại; hãy gỡ hook được quản lý trước, không ghi đè." >&2
    exit 1
  fi

  config_tmp="$CONFIG_FILE.tmp.$$"
  boot_tmp="$BOOT_FILE.tmp.$$"
  {
    printf '%s\n' "$CONFIG_MARKER"
    printf '%s\n' "$HM" "$VENV"
  } > "$config_tmp" || { rm -f "$config_tmp"; echo "LỖI: không ghi được cấu hình." >&2; exit 1; }
  chmod 600 "$config_tmp" || { rm -f "$config_tmp"; echo "LỖI: không đặt được quyền cấu hình." >&2; exit 1; }
  mv "$config_tmp" "$CONFIG_FILE" || { rm -f "$config_tmp"; echo "LỖI: không cài được cấu hình." >&2; exit 1; }

  cat > "$boot_tmp" <<'BOOT'
#!/system/bin/sh
# HERMES_TERMUX_BOOT_MANAGED=1
# Paths are read as plain data. Never source/eval this config file.
set -u
CONFIG="$HOME/.termux/boot/hermes-start.conf"
CONFIG_MARKER='# HERMES_TERMUX_BOOT_CONFIG_MANAGED=1'
[ -r "$CONFIG" ] || exit 1
{
  IFS= read -r marker || exit 1
  [ "$marker" = "$CONFIG_MARKER" ] || exit 1
  IFS= read -r HM || exit 1
  IFS= read -r VENV || exit 1
} < "$CONFIG"
[ -n "$HM" ] && [ -n "$VENV" ] || exit 1
export HERMES_HOME="$HM"
export HERMES_VENV="$VENV"
mkdir -p "$HM/logs" || exit 1
sh "$HM/scripts/no-root-watchdog.sh" start >> "$HM/logs/boot.log" 2>&1
BOOT
  if [ ! -s "$boot_tmp" ]; then
    rm -f "$boot_tmp" "$CONFIG_FILE"
    echo "LỖI: không ghi được boot hook." >&2
    exit 1
  fi
  chmod 700 "$boot_tmp" || { rm -f "$boot_tmp" "$CONFIG_FILE"; echo "LỖI: không đặt được quyền hook." >&2; exit 1; }
  mv "$boot_tmp" "$BOOT_FILE" || { rm -f "$boot_tmp" "$CONFIG_FILE"; echo "LỖI: không cài được boot hook." >&2; exit 1; }
  echo "Đã cài Termux:Boot hook: $BOOT_FILE"
  echo "Hoàn tác bằng: sh $HM/scripts/termux-boot.sh uninstall"
}

uninstall_boot() {
  if [ -e "$BOOT_FILE" ] && ! is_managed_file "$BOOT_FILE" "$BOOT_MARKER"; then
    echo "LỖI: hook hiện tại không có marker quản lý; không xóa." >&2
    exit 1
  fi
  if [ -e "$CONFIG_FILE" ] && ! is_managed_file "$CONFIG_FILE" "$CONFIG_MARKER"; then
    echo "LỖI: file cấu hình không có marker quản lý; không xóa." >&2
    exit 1
  fi
  [ ! -e "$BOOT_FILE" ] || rm -f "$BOOT_FILE" || { echo "LỖI: không xóa được hook." >&2; exit 1; }
  [ ! -e "$CONFIG_FILE" ] || rm -f "$CONFIG_FILE" || { echo "LỖI: không xóa được cấu hình." >&2; exit 1; }
  echo "Đã gỡ Hermes Termux:Boot hook/cấu hình. Watchdog/gateway đang chạy không bị dừng; dùng no-root-watchdog.sh stop nếu muốn dừng chúng."
}

case "${1:-}" in
  install) install_boot ;;
  uninstall) uninstall_boot ;;
  *)
    echo "usage: $0 {install|uninstall}" >&2
    echo "Cài đặt Hermes không tự bật Termux:Boot." >&2
    exit 2
    ;;
esac
