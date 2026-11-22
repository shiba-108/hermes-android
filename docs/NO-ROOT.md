# No-root on Android: Termux, Termux:Boot, and Shizuku

## The short answer

**“No Root, Like Root” is a hook, not a claim of root privileges.** The current installer has a non-root Termux path: project data defaults to `$HOME/.hermes-home`, the Python environment to `$HOME/hermes-venv`, and the Hermes Agent checkout to `$HOME/hermes-agent`. These paths can be overridden with `HERMES_HOME`, `HERMES_VENV`, and `HERMES_AGENT_DIR`.

The no-root watchdog can start and monitor only the Hermes gateway process it manages. It does not control other services or Android settings. Termux:Boot and Shizuku are optional and require explicit user actions. The implementation has not been verified on an Android device or emulator in this work; the commands below are documentation, not a device-test report.

## Install and run the gateway

Run `install.sh` from the repository checkout in Termux. Review its output: if a dependency step fails or is skipped, check the local install log and fix that before continuing. Configure Hermes Agent's provider and channel credentials locally, following the upstream instructions; do not put secrets in this repository.

Start, inspect, and stop the no-root watchdog with:

```sh
sh "$HOME/.hermes-home/scripts/no-root-watchdog.sh" start
sh "$HOME/.hermes-home/scripts/no-root-watchdog.sh" status
sh "$HOME/.hermes-home/scripts/no-root-watchdog.sh" stop
```

If you installed with custom paths, set `HERMES_HOME` and `HERMES_VENV` to the same values used during installation before running these commands. The watchdog supervises only its managed Hermes gateway. It does not start or manage Tailscale, the web UI, a DNS proxy, Android package settings, Doze, or Private DNS. Its process checks are defensive but do not prove that a channel connected or a model request succeeded; inspect the local logs and test the actual service.

## Optional startup after reboot with Termux:Boot

Termux:Boot is not enabled by the installer. Install it from a source compatible with your Termux app's signing key, open the Termux:Boot app once, and then explicitly install the Hermes hook:

```sh
sh "$HOME/.hermes-home/scripts/termux-boot.sh" install
```

The hook is written under `~/.termux/boot/` and starts the no-root watchdog after boot. If a hook or config file already exists without the Hermes management marker, the hook-install script refuses to overwrite it. Remove only the Hermes-managed hook with:

```sh
sh "$HOME/.hermes-home/scripts/termux-boot.sh" uninstall
```

Uninstalling the hook does **not** stop a watchdog or gateway that is already running. If you want to stop those too, run `no-root-watchdog.sh stop` separately. After a reboot, check the boot and watchdog logs, then verify that the gateway and the channel actually work. Android and manufacturer background restrictions can still stop Termux.

Termux:Boot's official README says scripts in `~/.termux/boot/` run in sorted order and suggests `termux-wake-lock` only if preventing sleep is desired. **The Hermes hook does not acquire a wake lock by default.** Termux documents both `termux-wake-lock` and `termux-wake-unlock`; a held lock can keep the device from deep sleep and increase battery use. If you deliberately opt in, manage the lock yourself, for example:

```sh
termux-wake-lock
sh "$HOME/.hermes-home/scripts/no-root-watchdog.sh" start
# Later, when the gateway no longer needs the lock:
sh "$HOME/.hermes-home/scripts/no-root-watchdog.sh" stop
termux-wake-unlock
```

Do not unlock while another Termux task still needs the lock. The hook does not automatically pair a lock with an unlock, and a wake lock cannot guarantee 24/7 uptime, connectivity, or provider availability. See the [Termux:Boot README](https://github.com/termux/termux-boot/blob/master/README.md) and [Termux wake-lock notes](https://wiki.termux.com/wiki/Termux-wake-lock).

## Optional Shizuku operations

This repository includes `scripts/shizuku-setup.sh`, an optional helper that uses `rish`. Install and start Shizuku yourself, install/configure `rish` in Termux using Shizuku's instructions, then grant the requested permission when prompted. Check readiness and available commands without making a system change:

```sh
sh "$HOME/.hermes-home/scripts/shizuku-setup.sh" status
sh "$HOME/.hermes-home/scripts/shizuku-setup.sh" --help
```

Shizuku is a **limited integration, not root**. These operations run only when explicitly called; neither installation nor the watchdog invokes them automatically.

- **Package state:** `pm show <package>` inspects one package. `pm disable <third-party-package>` only accepts the exact name of an installed third-party package. `pm enable <package>` only reverses a disable recorded by this helper. If a package was already disabled, the helper does not claim it can undo that pre-existing state.
- **Doze whitelist:** `deviceidle show <package>` inspects a package. `deviceidle add <third-party-package>` adds only the specified installed third-party package if it was not already present. `deviceidle remove <package>` only removes a whitelist entry recorded as added by this helper; a pre-existing entry is left alone.
- **Android Private DNS:** `private-dns show` inspects the setting; `private-dns set <hostname>` changes the **system-wide** Android Private DNS hostname; `private-dns restore` restores the saved earlier setting only if the current setting still matches the helper's change. Review the hostname and understand that this affects DNS for the device, not just Hermes.

For example, after Shizuku/rish is ready:

```sh
sh "$HOME/.hermes-home/scripts/shizuku-setup.sh" pm show com.example.app
sh "$HOME/.hermes-home/scripts/shizuku-setup.sh" deviceidle show com.termux
sh "$HOME/.hermes-home/scripts/shizuku-setup.sh" private-dns show
```

Any setting-changing command should be a deliberate choice. Check the helper's `--help` output for exact syntax and reversal commands before using `pm disable`, `deviceidle add`, or `private-dns set`. Android/ROM support and Shizuku permissions can vary. Shizuku's wireless-debugging startup on Android 11+ must be repeated after reboot under current system limitations; see the [official Shizuku setup guide](https://shizuku.rikka.app/guide/setup/).

Android Private DNS uses **DNS-over-TLS (DoT), not DNS-over-HTTPS (DoH)**. Shizuku's shell-level access does not provide root, `iptables`, or a VPN service, so this helper does not create transparent system-wide DoH.

## Other limitations and security notes

- There is no 24/7 uptime guarantee. Power management, OEM restrictions, battery/thermal conditions, network availability, and provider limits can interrupt the gateway.
- No-root web UI starts on `127.0.0.1` by default. It has no authentication. Setting `WEBUI_HOST` explicitly can expose it remotely; prefer a trusted interface such as the device's Tailscale address and do not expose it to the public internet. The existing root default remains `0.0.0.0` and is also unauthenticated. See [`../web/README.md`](../web/README.md).
- Shizuku does not make the Magisk `service.d/` scripts, `iptables`, or other root-only operations available to ordinary Termux.
- A successful shell command or a running PID does not prove that Telegram or another channel is connected, or that provider/model requests work. Verify the actual service on your device.

## Sources

- [Termux:Boot official README](https://github.com/termux/termux-boot/blob/master/README.md)
- [Termux wake-lock and wake-unlock notes](https://wiki.termux.com/wiki/Termux-wake-lock)
- [Shizuku official setup guide](https://shizuku.rikka.app/guide/setup/)
- [Shizuku project repository](https://github.com/RikkaApps/Shizuku)
- [Hermes Agent upstream repository](https://github.com/NousResearch/hermes-agent)

---

# Android không root: Termux, Termux:Boot và Shizuku

## Tóm tắt

**“No Root, Like Root” là câu hook, không phải tuyên bố có quyền root.** Installer hiện có nhánh cài Termux không root: dữ liệu dự án mặc định ở `$HOME/.hermes-home`, môi trường Python ở `$HOME/hermes-venv` và mã Hermes Agent ở `$HOME/hermes-agent`. Có thể đổi các đường dẫn này bằng `HERMES_HOME`, `HERMES_VENV` và `HERMES_AGENT_DIR`.

Watchdog no-root chỉ khởi chạy và giám sát tiến trình Hermes gateway do chính nó quản lý. Nó không điều khiển dịch vụ khác hay cài đặt Android. Termux:Boot và Shizuku đều là tùy chọn, cần người dùng chủ động thao tác. Trong phần công việc này, implementation chưa được xác minh trên thiết bị Android hoặc emulator; các lệnh dưới đây là hướng dẫn, không phải báo cáo đã test trên máy.

## Cài và chạy gateway

Chạy `install.sh` từ checkout của repo trong Termux. Đọc kết quả: nếu bước cài phụ thuộc bị lỗi hoặc bỏ qua, hãy xem log cài đặt trên máy và xử lý trước khi tiếp tục. Tự cấu hình provider và credential kênh cho Hermes Agent theo hướng dẫn upstream; không đưa secret vào repo.

Khởi động, kiểm tra và dừng watchdog no-root:

```sh
sh "$HOME/.hermes-home/scripts/no-root-watchdog.sh" start
sh "$HOME/.hermes-home/scripts/no-root-watchdog.sh" status
sh "$HOME/.hermes-home/scripts/no-root-watchdog.sh" stop
```

Nếu cài bằng đường dẫn tùy chỉnh, hãy đặt `HERMES_HOME` và `HERMES_VENV` đúng như lúc cài trước khi chạy các lệnh. Watchdog chỉ giám sát Hermes gateway do nó quản lý. Nó không khởi chạy hoặc quản lý Tailscale, web UI, proxy DNS, cài đặt package Android, Doze hay Private DNS. Cơ chế kiểm tra process có biện pháp thận trọng nhưng không chứng minh kênh đã kết nối hay model request thành công; hãy kiểm tra log cục bộ và thử dịch vụ thực tế.

## Tùy chọn tự chạy sau reboot bằng Termux:Boot

Installer không tự bật Termux:Boot. Cài Termux:Boot từ nguồn tương thích với khóa ký của ứng dụng Termux, mở ứng dụng Termux:Boot một lần, rồi chủ động cài hook Hermes:

```sh
sh "$HOME/.hermes-home/scripts/termux-boot.sh" install
```

Hook được đặt dưới `~/.termux/boot/` và chạy watchdog no-root sau khi boot. Nếu đã có hook hoặc file cấu hình không mang marker quản lý của Hermes, script cài hook sẽ từ chối ghi đè. Chỉ gỡ hook do Hermes quản lý bằng:

```sh
sh "$HOME/.hermes-home/scripts/termux-boot.sh" uninstall
```

Gỡ hook **không** dừng watchdog hoặc gateway đang chạy. Nếu muốn dừng cả hai, chạy riêng `no-root-watchdog.sh stop`. Sau reboot, hãy kiểm tra log boot/watchdog rồi xác minh gateway và kênh thực sự hoạt động. Android và giới hạn chạy nền của từng hãng vẫn có thể dừng Termux.

README chính thức Termux:Boot nói các script trong `~/.termux/boot/` chạy theo thứ tự tên và gợi ý `termux-wake-lock` nếu người dùng muốn ngăn máy ngủ. **Hook Hermes mặc định không bật wake lock.** Termux có cả `termux-wake-lock` và `termux-wake-unlock`; lock đang giữ có thể ngăn máy vào deep sleep và làm hao pin. Nếu chủ động chọn bật, hãy tự quản lý lock, ví dụ:

```sh
termux-wake-lock
sh "$HOME/.hermes-home/scripts/no-root-watchdog.sh" start
# Sau này, khi gateway không còn cần lock:
sh "$HOME/.hermes-home/scripts/no-root-watchdog.sh" stop
termux-wake-unlock
```

Không nhả lock khi một tác vụ Termux khác vẫn cần nó. Hook không tự ghép lệnh lock với unlock; wake lock cũng không bảo đảm uptime 24/7, mạng hay provider luôn sẵn sàng. Xem [README Termux:Boot](https://github.com/termux/termux-boot/blob/master/README.md) và [ghi chú wake-lock của Termux](https://wiki.termux.com/wiki/Termux-wake-lock).

## Thao tác Shizuku tùy chọn

Repo có helper tùy chọn `scripts/shizuku-setup.sh`, sử dụng `rish`. Tự cài và khởi động Shizuku, cài/cấu hình `rish` trong Termux theo hướng dẫn của Shizuku, rồi cấp quyền khi được hỏi. Kiểm tra trạng thái và lệnh có sẵn mà không thay đổi hệ thống:

```sh
sh "$HOME/.hermes-home/scripts/shizuku-setup.sh" status
sh "$HOME/.hermes-home/scripts/shizuku-setup.sh" --help
```

Shizuku là **tích hợp giới hạn, không phải root**. Các thao tác chỉ chạy khi bạn gọi rõ ràng; installer và watchdog không tự gọi chúng.

- **Trạng thái package:** `pm show <package>` xem một package. `pm disable <third-party-package>` chỉ nhận chính xác tên một ứng dụng bên thứ ba đã cài. `pm enable <package>` chỉ hoàn tác trạng thái disable có bản ghi do helper này tạo. Nếu package đã bị disable từ trước, helper không nhận quyền hoàn tác trạng thái có sẵn đó.
- **Doze whitelist:** `deviceidle show <package>` xem package. `deviceidle add <third-party-package>` chỉ thêm package bên thứ ba được chỉ rõ nếu package chưa có trong whitelist. `deviceidle remove <package>` chỉ gỡ mục có bản ghi do helper thêm; mục có sẵn được giữ nguyên.
- **Android Private DNS:** `private-dns show` xem cài đặt; `private-dns set <hostname>` đổi hostname Android Private DNS **toàn hệ thống**; `private-dns restore` chỉ khôi phục cấu hình đã lưu nếu cài đặt hiện tại vẫn khớp với thay đổi do helper tạo. Hãy xem hostname và hiểu rằng thay đổi này ảnh hưởng DNS của cả thiết bị, không chỉ Hermes.

Ví dụ sau khi Shizuku/rish đã sẵn sàng:

```sh
sh "$HOME/.hermes-home/scripts/shizuku-setup.sh" pm show com.example.app
sh "$HOME/.hermes-home/scripts/shizuku-setup.sh" deviceidle show com.termux
sh "$HOME/.hermes-home/scripts/shizuku-setup.sh" private-dns show
```

Mọi lệnh đổi cài đặt cần được cân nhắc chủ động. Trước khi dùng `pm disable`, `deviceidle add` hay `private-dns set`, hãy xem `--help` để biết cú pháp và lệnh hoàn tác chính xác. Hỗ trợ Android/ROM và quyền Shizuku có thể khác nhau. Theo giới hạn hiện tại của hệ thống, cách khởi chạy Shizuku bằng wireless debugging trên Android 11+ cần thực hiện lại sau khi reboot; xem [hướng dẫn setup chính thức của Shizuku](https://shizuku.rikka.app/guide/setup/).

Android Private DNS dùng **DNS-over-TLS (DoT), không phải DNS-over-HTTPS (DoH)**. Quyền shell qua Shizuku không cấp root, `iptables` hay VPN service, vì vậy helper không tạo DoH trong suốt cho toàn hệ thống.

## Giới hạn khác và lưu ý an toàn

- Không bảo đảm chạy 24/7. Quản lý pin, giới hạn của hãng, tình trạng pin/nhiệt độ, mạng và hạn mức provider đều có thể làm gateway gián đoạn.
- Web UI no-root mặc định bind `127.0.0.1` và không có xác thực. Đặt `WEBUI_HOST` rõ ràng có thể mở truy cập từ xa; nên dùng giao diện tin cậy như địa chỉ Tailscale của máy và không mở ra Internet công cộng. Root vẫn mặc định bind `0.0.0.0` và cũng không có xác thực. Xem [`../web/README.md`](../web/README.md).
- Shizuku không khiến script Magisk `service.d/`, `iptables` hoặc thao tác chỉ dành cho root chạy được trong Termux thông thường.
- Lệnh shell thành công hoặc PID còn tồn tại không chứng minh Telegram/kênh đã kết nối hoặc provider/model hoạt động. Hãy xác minh dịch vụ thực tế trên thiết bị.

## Nguồn

- [README Termux:Boot chính thức](https://github.com/termux/termux-boot/blob/master/README.md)
- [Ghi chú Termux về wake-lock và wake-unlock](https://wiki.termux.com/wiki/Termux-wake-lock)
- [Hướng dẫn Shizuku chính thức](https://shizuku.rikka.app/guide/setup/)
- [Repo Shizuku](https://github.com/RikkaApps/Shizuku)
- [Repo Hermes Agent upstream](https://github.com/NousResearch/hermes-agent)
