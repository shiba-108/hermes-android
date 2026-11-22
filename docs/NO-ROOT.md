# Chạy Hermes trên Android không root

Installer v2 tự phân nhánh theo quyền hiện tại. Root + Magisk tiếp tục dùng nguyên luồng `service.d/`; Termux không root cài dữ liệu vào `$HOME/.hermes-home`, venv vào `$HOME/hermes-venv` và mã Hermes vào `$HOME/hermes-agent` (có thể đổi bằng `HERMES_HOME`, `HERMES_VENV`, `HERMES_AGENT_DIR`). Nhánh no-root không ghi vào `/data/adb`, không tự bật boot hook và không thay đổi package, Doze hay DNS hệ thống.

## Chạy và dừng watchdog

Trong Termux sau khi cài đặt:

```sh
sh "$HOME/.hermes-home/scripts/no-root-watchdog.sh" start
sh "$HOME/.hermes-home/scripts/no-root-watchdog.sh" status
sh "$HOME/.hermes-home/scripts/no-root-watchdog.sh" stop
```

Watchdog chỉ khởi chạy/giám sát Hermes gateway do chính nó quản lý; log nằm ở `$HOME/.hermes-home/logs/`. `stop` dừng watchdog và gateway có PID do script ghi nhận. Nó không điều khiển Tailscale, DoH hay Android settings. Nếu cài bằng đường dẫn tùy chỉnh, đặt `HERMES_HOME` và `HERMES_VENV` tương ứng trước khi gọi.

## Tự khởi động bằng Termux:Boot (tùy chọn)

Cài Termux:Boot từ cùng nguồn cài Termux, mở ứng dụng một lần, rồi **chủ động** đăng ký hook:

```sh
sh "$HOME/.hermes-home/scripts/termux-boot.sh" install
```

Gỡ hook mà không xóa dữ liệu Hermes:

```sh
sh "$HOME/.hermes-home/scripts/termux-boot.sh" uninstall
```

Installer không chạy lệnh `install` này tự động. Nếu hook cùng tên đã có nhưng không do Hermes tạo, script từ chối ghi đè/xóa. Termux:Boot vẫn phụ thuộc vào chính sách pin và giới hạn nền của thiết bị; không bảo đảm ứng dụng không bao giờ bị hệ điều hành dừng.

## Shizuku là tùy chọn, không phải root

Muốn dùng các thao tác bên dưới, người dùng tự cài và khởi động Shizuku, cài `rish` vào Termux theo hướng dẫn trong ứng dụng Shizuku, rồi cấp quyền khi Android/Shizuku hỏi. Kiểm tra trước, không đổi gì:

```sh
sh "$HOME/.hermes-home/scripts/shizuku-setup.sh" status
```

Các lệnh chỉ hoạt động sau lời gọi rõ ràng:

- **Package:** `pm disable <package>` chỉ nhận package ứng dụng bên thứ ba chính xác, không chạy danh sách hàng loạt hay đụng package hệ thống. Script ghi lại đúng package nó disable; `pm enable <package>` chỉ hoàn tác mục có bản ghi đó. Nếu ứng dụng vốn đã disabled, script không nhận quyền hoàn tác trạng thái có sẵn.
- **Doze:** `deviceidle add com.termux` chỉ thêm đúng package vào whitelist; `deviceidle remove com.termux` chỉ gỡ nếu script đã thêm. Mục đã có từ trước được giữ nguyên.
- **DNS mã hóa của Android:** `private-dns set <hostname>` đổi DNS **toàn hệ thống** sang hostname mà người dùng chỉ định. Script lưu cấu hình trước đó; `private-dns restore` chỉ khôi phục khi cài đặt hiện tại vẫn trùng với thay đổi do script đặt, để tránh ghi đè một đổi DNS khác.

Android Private DNS dùng DNS-over-TLS (DoT), **không phải** DNS-over-HTTPS (DoH). Shizuku chạy với quyền shell, không cấp root/iptables hay VPNService, vì vậy công cụ này không bật DoH xuyên suốt hệ thống. Không có tính năng Shizuku nào được tự chạy khi cài đặt hoặc khởi động watchdog. `service.d/04-doh.sh` trong luồng root không bị thay đổi.

Xem danh sách lệnh và trạng thái bằng:

```sh
sh "$HOME/.hermes-home/scripts/shizuku-setup.sh" --help
```
