#!/system/bin/sh
# Optional Shizuku operations. Nothing runs unless the user explicitly calls it.
# Shizuku grants shell-level access, not root. No iptables, package-wide sweeps,
# hidden permission grants, or automatic changes are performed here.
set -u

USER_HOME=${HOME:-/data/data/com.termux/files/home}
HM=${HERMES_HOME:-$USER_HOME/.hermes-home}
STATE="$HM/shizuku-state"
RISH=${RISH_EXECUTABLE:-$(command -v rish 2>/dev/null || true)}

usage() {
  cat <<'USAGE'
Shizuku helper (mọi lệnh thay đổi đều phải gọi chủ động):
  shizuku-setup.sh status
  shizuku-setup.sh pm show <package>
  shizuku-setup.sh pm disable <third-party-package>
  shizuku-setup.sh pm enable <package>              # chỉ hoàn tác gói script đã disable
  shizuku-setup.sh deviceidle show <package>
  shizuku-setup.sh deviceidle add <package>
  shizuku-setup.sh deviceidle remove <package>      # chỉ gỡ mục script đã thêm
  shizuku-setup.sh private-dns show
  shizuku-setup.sh private-dns set <hostname>
  shizuku-setup.sh private-dns restore

Private DNS của Android là DNS-over-TLS (DoT), không phải DoH.
Shizuku không cấp root/iptables; script không giả lập transparent DoH.
USAGE
}

fail() { echo "LỖI: $*" >&2; exit 1; }

check_rish() {
  [ -n "$RISH" ] || fail "không tìm thấy rish. Cài/cấu hình Shizuku và rish trong Termux trước."
  command -v "$RISH" >/dev/null 2>&1 || [ -x "$RISH" ] || fail "rish không chạy được: $RISH"
  "$RISH" -c 'id' >/dev/null 2>&1 || fail "rish/Shizuku chưa sẵn sàng hoặc quyền Shizuku chưa được cấp. Mở Shizuku và cấp quyền rõ ràng rồi thử lại."
}

rish() { "$RISH" -c "$1"; }

valid_package() {
  case "${1:-}" in ''|*[!A-Za-z0-9._]*) return 1 ;; esac
  case "$1" in .*|*.|*..*) return 1 ;; esac
  return 0
}

valid_hostname() {
  case "${1:-}" in ''|*[!A-Za-z0-9.-]*) return 1 ;; esac
  case "$1" in .*|*.|*..*|-*|*-) return 1 ;; esac
  return 0
}

is_third_party_package() {
  pkg=$1
  output=$(rish "pm list packages -3" 2>/dev/null) || return 1
  printf '%s\n' "$output" | grep -F -x "package:$pkg" >/dev/null 2>&1
}

is_disabled() {
  pkg=$1
  output=$(rish 'pm list packages -d' 2>/dev/null) || fail "không đọc được trạng thái package disabled qua Shizuku"
  printf '%s\n' "$output" | grep -F -x "package:$pkg" >/dev/null 2>&1
}

ensure_state_dir() { mkdir -p "$STATE" 2>/dev/null || fail "không tạo được $STATE"; }

pm_show() {
  pkg=$1
  valid_package "$pkg" || fail "tên package không hợp lệ"
  if is_third_party_package "$pkg"; then
    if is_disabled "$pkg"; then echo "$pkg: third-party, disabled"; else echo "$pkg: third-party, enabled"; fi
  else
    echo "$pkg: không thấy trong danh sách ứng dụng bên thứ ba; script không tác động package hệ thống."
  fi
}

pm_disable() {
  pkg=$1
  valid_package "$pkg" || fail "tên package không hợp lệ"
  is_third_party_package "$pkg" || fail "chỉ cho phép package chính xác trong 'pm list packages -3'; không tác động package hệ thống."
  ensure_state_dir
  if is_disabled "$pkg"; then
    echo "$pkg đã bị disable từ trước; không đổi và không nhận quyền hoàn tác cho trạng thái cũ."
    return 0
  fi
  if [ -f "$STATE/pm-disabled" ]; then
    recorded=$(cat "$STATE/pm-disabled" 2>/dev/null)
    [ "$recorded" = "$pkg" ] || fail "đang theo dõi package $recorded; hãy hoàn tác package đó trước."
  fi
  echo "Sẽ disable duy nhất package bên thứ ba: $pkg (user 0). Hoàn tác bằng: pm enable $pkg"
  printf '%s\n' "$pkg" > "$STATE/pm-disabled" || fail "không ghi được trạng thái hoàn tác"
  if ! rish "pm disable-user --user 0 $pkg"; then
    rm -f "$STATE/pm-disabled"
    fail "pm disable-user thất bại; package chưa được ghi nhận là đã đổi"
  fi
  if is_disabled "$pkg"; then
    echo "Đã disable $pkg. Hoàn tác: sh $0 pm enable $pkg"
  else
    rm -f "$STATE/pm-disabled"
    fail "không xác minh được trạng thái disabled; kiểm tra bằng pm show"
  fi
}

pm_enable() {
  pkg=$1
  valid_package "$pkg" || fail "tên package không hợp lệ"
  [ -f "$STATE/pm-disabled" ] || fail "script không có bản ghi disable do nó tạo; không tự enable trạng thái khác."
  recorded=$(cat "$STATE/pm-disabled" 2>/dev/null)
  [ "$recorded" = "$pkg" ] || fail "script chỉ có thể hoàn tác package $recorded."
  if ! is_disabled "$pkg"; then
    rm -f "$STATE/pm-disabled"
    echo "$pkg hiện đã enabled; không đổi trạng thái, đã dọn bản ghi cũ."
    return 0
  fi
  echo "Sẽ enable lại package đã được script disable: $pkg (user 0)."
  rish "pm enable --user 0 $pkg" || fail "pm enable thất bại; giữ bản ghi để có thể thử lại."
  if is_disabled "$pkg"; then fail "package vẫn báo disabled; giữ bản ghi để thử lại."; fi
  rm -f "$STATE/pm-disabled"
  echo "Đã enable lại $pkg."
}

contains_exact_package() {
  expected=$1
  text=$2
  printf '%s\n' "$text" | awk -v wanted="$expected" '
    {
      line = $0
      gsub(/[^A-Za-z0-9_.]+/, " ", line)
      count = split(line, parts, /[[:space:]]+/)
      for (i = 1; i <= count; i++) if (parts[i] == wanted) found = 1
    }
    END { exit found ? 0 : 1 }
  '
}

deviceidle_show() {
  pkg=$1
  valid_package "$pkg" || fail "tên package không hợp lệ"
  output=$(rish 'dumpsys deviceidle whitelist' 2>/dev/null) || fail "không đọc được deviceidle whitelist"
  if contains_exact_package "$pkg" "$output"; then
    echo "$pkg đang nằm trong deviceidle whitelist."
  else
    echo "$pkg không nằm trong deviceidle whitelist."
  fi
}

deviceidle_add() {
  pkg=$1
  valid_package "$pkg" || fail "tên package không hợp lệ"
  is_third_party_package "$pkg" || fail "chỉ cho phép package chính xác của ứng dụng bên thứ ba đã cài."
  ensure_state_dir
  if [ -f "$STATE/deviceidle-added" ]; then
    recorded=$(cat "$STATE/deviceidle-added" 2>/dev/null)
    [ "$recorded" = "$pkg" ] || fail "đang theo dõi whitelist $recorded; hãy hoàn tác mục đó trước."
  fi
  output=$(rish 'dumpsys deviceidle whitelist' 2>/dev/null) || fail "không đọc được deviceidle whitelist"
  if contains_exact_package "$pkg" "$output"; then
    echo "$pkg đã có trong whitelist; không đổi và không nhận quyền hoàn tác trạng thái cũ."
    return 0
  fi
  echo "Sẽ thêm duy nhất $pkg vào deviceidle whitelist; hoàn tác bằng deviceidle remove $pkg."
  printf '%s\n' "$pkg" > "$STATE/deviceidle-added" || fail "không ghi được trạng thái hoàn tác"
  if ! rish "cmd deviceidle whitelist +$pkg"; then
    rm -f "$STATE/deviceidle-added"
    fail "không thêm được whitelist; có thể Android không hỗ trợ cmd deviceidle trên bản này."
  fi
  output=$(rish 'dumpsys deviceidle whitelist' 2>/dev/null) || output=
  if contains_exact_package "$pkg" "$output"; then
    echo "Đã thêm $pkg. Hoàn tác: sh $0 deviceidle remove $pkg"
  else
    rm -f "$STATE/deviceidle-added"
    fail "không xác minh được whitelist; kiểm tra bằng deviceidle show $pkg"
  fi
}

deviceidle_remove() {
  pkg=$1
  valid_package "$pkg" || fail "tên package không hợp lệ"
  [ -f "$STATE/deviceidle-added" ] || fail "script không có bản ghi whitelist do nó tạo; không gỡ mục có sẵn."
  recorded=$(cat "$STATE/deviceidle-added" 2>/dev/null)
  [ "$recorded" = "$pkg" ] || fail "script chỉ có thể hoàn tác mục $recorded."
  output=$(rish 'dumpsys deviceidle whitelist' 2>/dev/null) || fail "không đọc được deviceidle whitelist"
  if ! contains_exact_package "$pkg" "$output"; then
    rm -f "$STATE/deviceidle-added"
    echo "$pkg đã bị gỡ trước đó; không đổi, đã dọn bản ghi cũ."
    return 0
  fi
  echo "Sẽ gỡ duy nhất whitelist do script đã thêm: $pkg."
  rish "cmd deviceidle whitelist -$pkg" || fail "gỡ whitelist thất bại; giữ bản ghi để thử lại."
  output=$(rish 'dumpsys deviceidle whitelist' 2>/dev/null) || output=
  if contains_exact_package "$pkg" "$output"; then
    fail "package vẫn trong whitelist; giữ bản ghi để thử lại."
  fi
  rm -f "$STATE/deviceidle-added"
  echo "Đã gỡ $pkg khỏi whitelist."
}

private_dns_show() {
  mode=$(rish 'settings get global private_dns_mode' 2>/dev/null) || fail "không đọc được private_dns_mode"
  host=$(rish 'settings get global private_dns_specifier' 2>/dev/null) || fail "không đọc được private_dns_specifier"
  echo "Android Private DNS mode: $mode"
  echo "Provider hostname: $host"
  echo "Lưu ý: Private DNS của Android mã hóa DNS bằng TLS (DoT), không phải HTTPS/DoH."
}

private_dns_set() {
  host=$1
  valid_hostname "$host" || fail "hostname không hợp lệ; chỉ dùng chữ, số, dấu chấm và gạch nối."
  ensure_state_dir
  if [ -f "$STATE/private-dns-host" ]; then
    recorded=$(cat "$STATE/private-dns-host" 2>/dev/null)
    [ "$recorded" = "$host" ] || fail "đang theo dõi Private DNS $recorded; hãy restore trước khi đặt host khác."
  fi
  old_mode=$(rish 'settings get global private_dns_mode' 2>/dev/null) || fail "không đọc được private_dns_mode"
  old_host=$(rish 'settings get global private_dns_specifier' 2>/dev/null) || fail "không đọc được private_dns_specifier"
  if [ "$old_mode" = hostname ] && [ "$old_host" = "$host" ]; then
    echo "Android Private DNS đã dùng $host; không đổi và không nhận quyền hoàn tác trạng thái cũ."
    return 0
  fi
  case "$old_mode:$old_host" in *[!A-Za-z0-9._:-]*) fail "giá trị Private DNS hiện tại không ở dạng an toàn để sao lưu tự động; không đổi." ;; esac
  echo "Sẽ đổi DNS toàn hệ thống sang Android Private DNS hostname=$host (DoT, không phải DoH)."
  printf '%s\n' "$old_mode" > "$STATE/private-dns-old-mode" || fail "không lưu được cấu hình cũ"
  printf '%s\n' "$old_host" > "$STATE/private-dns-old-host" || fail "không lưu được cấu hình cũ"
  printf '%s\n' "$host" > "$STATE/private-dns-host" || fail "không lưu được hostname mới"
  if ! rish "settings put global private_dns_specifier $host" || ! rish 'settings put global private_dns_mode hostname'; then
    fail "không áp dụng được Private DNS; chạy private-dns show và restore nếu cần."
  fi
  actual_mode=$(rish 'settings get global private_dns_mode' 2>/dev/null) || actual_mode=
  actual_host=$(rish 'settings get global private_dns_specifier' 2>/dev/null) || actual_host=
  if [ "$actual_mode" != hostname ] || [ "$actual_host" != "$host" ]; then
    fail "không xác minh được DNS mới; chạy private-dns show và restore nếu cấu hình đã đổi."
  fi
  echo "Đã đặt Private DNS=$host. Hoàn tác bằng: sh $0 private-dns restore"
}

private_dns_restore() {
  [ -f "$STATE/private-dns-host" ] && [ -f "$STATE/private-dns-old-mode" ] && [ -f "$STATE/private-dns-old-host" ] || \
    fail "không có bản sao Private DNS do script tạo để hoàn tác."
  managed_host=$(cat "$STATE/private-dns-host" 2>/dev/null)
  old_mode=$(cat "$STATE/private-dns-old-mode" 2>/dev/null)
  old_host=$(cat "$STATE/private-dns-old-host" 2>/dev/null)
  current_mode=$(rish 'settings get global private_dns_mode' 2>/dev/null) || fail "không đọc được mode hiện tại"
  current_host=$(rish 'settings get global private_dns_specifier' 2>/dev/null) || fail "không đọc được hostname hiện tại"
  if [ "$current_mode" = "$old_mode" ] && [ "$current_host" = "$old_host" ]; then
    rm -f "$STATE/private-dns-host" "$STATE/private-dns-old-mode" "$STATE/private-dns-old-host"
    echo "Private DNS đã ở cấu hình cũ; không đổi, đã dọn bản ghi."
    return 0
  fi
  if { [ "$current_mode" = hostname ] && [ "$current_host" = "$managed_host" ]; } || \
     { [ "$current_mode" = "$old_mode" ] && [ "$current_host" = "$managed_host" ]; }; then
    :
  else
    fail "cài đặt hiện tại đã khác trạng thái do script tạo; không ghi đè thay đổi khác. Xem private-dns show và chỉnh tay nếu cần."
  fi
  case "$old_mode:$old_host" in *[!A-Za-z0-9._:-]*) fail "bản sao cũ không hợp lệ; không ghi cấu hình." ;; esac
  echo "Sẽ khôi phục Private DNS về mode=$old_mode, hostname=$old_host."
  if [ "$old_host" = null ] || [ -z "$old_host" ]; then
    rish 'settings delete global private_dns_specifier' || fail "khôi phục hostname thất bại; giữ bản sao."
  else
    rish "settings put global private_dns_specifier $old_host" || fail "khôi phục hostname thất bại; giữ bản sao."
  fi
  if [ "$old_mode" = null ] || [ -z "$old_mode" ]; then
    rish 'settings delete global private_dns_mode' || fail "khôi phục mode thất bại; giữ bản sao."
  else
    rish "settings put global private_dns_mode $old_mode" || fail "khôi phục mode thất bại; giữ bản sao."
  fi
  rm -f "$STATE/private-dns-host" "$STATE/private-dns-old-mode" "$STATE/private-dns-old-host"
  echo "Đã khôi phục Private DNS trước đó."
}

case "${1:-}" in
  status)
    check_rish
    echo "Shizuku/rish sẵn sàng; không thay đổi cấu hình."
    rish 'id'
    ;;
  pm)
    check_rish
    [ "$#" -ge 3 ] || { usage; exit 2; }
    case "$2" in
      show) [ "$#" -eq 3 ] || { usage; exit 2; }; pm_show "$3" ;;
      disable) [ "$#" -eq 3 ] || { usage; exit 2; }; pm_disable "$3" ;;
      enable) [ "$#" -eq 3 ] || { usage; exit 2; }; pm_enable "$3" ;;
      *) usage; exit 2 ;;
    esac
    ;;
  deviceidle)
    check_rish
    [ "$#" -eq 3 ] || { usage; exit 2; }
    case "$2" in
      show) deviceidle_show "$3" ;;
      add) deviceidle_add "$3" ;;
      remove) deviceidle_remove "$3" ;;
      *) usage; exit 2 ;;
    esac
    ;;
  private-dns)
    check_rish
    case "${2:-}" in
      show) [ "$#" -eq 2 ] || { usage; exit 2; }; private_dns_show ;;
      set) [ "$#" -eq 3 ] || { usage; exit 2; }; private_dns_set "$3" ;;
      restore) [ "$#" -eq 2 ] || { usage; exit 2; }; private_dns_restore ;;
      *) usage; exit 2 ;;
    esac
    ;;
  -h|--help|help|'') usage ;;
  *) usage; exit 2 ;;
esac
