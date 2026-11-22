# hermes-android

## “No Root, Like Root” — a hook, not a privilege claim

`hermes-android` provides scripts for setting up and running the [Hermes Agent](https://github.com/NousResearch/hermes-agent) gateway on Android. The installer detects privilege level and Magisk; it copies the `service.d/` boot scripts only when both root and Magisk are present, while non-root Termux uses a separate user-home path.

> **Reality check:** no-root means the app runs in Termux's own user space. It does not gain root. The optional Shizuku helper can perform a few explicitly requested Android operations through `rish`; it is not general root access. Device compatibility and continuous uptime are not guaranteed.

[English](#english) · [Tiếng Việt](#tiếng-việt)

---

## English

### What the installer does

- **Root + Magisk:** keeps the repository's `service.d/` boot-script path. The installer copies those scripts only when it detects both root and Magisk.
- **Non-root Termux:** installs project files under `$HOME/.hermes-home`, the Python environment under `$HOME/hermes-venv`, and the upstream Hermes Agent checkout under `$HOME/hermes-agent`. Set `HERMES_HOME`, `HERMES_VENV`, or `HERMES_AGENT_DIR` before installing to override those defaults.
- The installer attempts to prepare Hermes Agent and its dependencies. Missing tools, network failures, or unsupported environments can cause steps to be skipped with warnings; review the output and local logs.

The no-root watchdog is opt-in and manages only the Hermes gateway process it starts. It does not manage Tailscale, the web UI, DoH, Android package state, Doze, or Private DNS. Termux:Boot is also opt-in: the installer does not register a boot hook automatically.

### Getting started

Run the installer from a local checkout:

```sh
sh ./install.sh
```

For **non-root Termux**, configure your Hermes provider and channel credentials locally, then start and check the gateway watchdog:

```sh
sh "$HOME/.hermes-home/scripts/no-root-watchdog.sh" start
sh "$HOME/.hermes-home/scripts/no-root-watchdog.sh" status
```

To start it after reboot, install and open Termux:Boot once, then explicitly register the hook:

```sh
sh "$HOME/.hermes-home/scripts/termux-boot.sh" install
```

See [`docs/NO-ROOT.md`](docs/NO-ROOT.md) for the full no-root and Shizuku guide, including stop, uninstall, and restore commands. For **root + Magisk**, the `service.d/` path takes effect after reboot.

The installer does not create provider accounts or supply credentials. Store secrets on your device, never in this repository. Provider prices, free tiers, quotas, and model availability depend on the provider; this project does not guarantee free or unlimited usage.

### What “No Root, Like Root” does—and does not—mean

The optional `scripts/shizuku-setup.sh` helper uses Shizuku's `rish` shell bridge only when you call it. It supports narrowly scoped commands for an exact third-party package, a Doze whitelist entry, and Android Private DNS. It does not grant root, provide `iptables` access, or implement system-wide DNS-over-HTTPS. Android Private DNS changes a **device-wide** setting and uses DNS-over-TLS (DoT), not DoH. Some operations and permissions vary by Android version and manufacturer; inspect the command help and understand each change before using it.

### Limits and safety notes

- **No 24/7 promise:** Android power management, manufacturer background limits, heat, battery condition, connectivity, and provider availability can interrupt service. A wake lock can increase battery use and still cannot guarantee uptime.
- **No Android verification claim for this no-root revision:** shell syntax and simulated behavior checks are not a substitute for a real Android device or emulator run.
- **Web UI:** it has no authentication. No-root defaults to `127.0.0.1`; remote binding requires explicitly setting `WEBUI_HOST`. The existing root default is `0.0.0.0`, which listens on all interfaces. Do not expose the unauthenticated UI to an untrusted network or the public internet. See [`web/README.md`](web/README.md).
- **Root-only helpers:** the Magisk `service.d/` scripts are not made available to ordinary Termux by changing `HERMES_HOME` or starting Shizuku.
- **Root-script side effects:** review `service.d/` before using it. `02-adbd.sh` sets ADB-over-TCP on port 5555 and restarts `adbd`; avoid untrusted networks. `04-doh.sh` starts a local proxy and adds a root `iptables` NAT rule. These are separate from the no-root Shizuku helper.
- **Preflight lock risk:** `scripts/preflight_venv.sh` currently interpolates lock entries into Python source. Until fixed, do not run it with an untrusted lock or one a less-privileged account can modify, especially in a root/Magisk context.
- **Secrets and backups:** never commit credentials, session data, private configuration, or unredacted logs. If encryption tools or a recipient are not configured, `scripts/backup.sh` can leave a plaintext archive on-device; do not upload it. Read [`docs/BACKUP.md`](docs/BACKUP.md) first.

### Project notes

- [Device notes and test reports](docs/DEVICES.md) — distinguish project reports from verification of this no-root revision.
- [No-root, Termux:Boot, and Shizuku guide](docs/NO-ROOT.md)
- [Web UI guide](web/README.md)
- [Contributing](CONTRIBUTING.md)
- [License](LICENSE)

`docs/demo-telegram.svg` is an illustrative mockup, not a live capture or evidence of telemetry. No real video footage or MP4 is included; the TikTok material is a storyboard and script only in [`docs/TIKTOK.md`](docs/TIKTOK.md).

---

## Tiếng Việt

### Installer làm gì?

- **Root + Magisk:** giữ luồng script khởi động `service.d/` hiện có. Installer chỉ chép các script này khi phát hiện đồng thời root và Magisk.
- **Termux không root:** cài tệp dự án dưới `$HOME/.hermes-home`, môi trường Python dưới `$HOME/hermes-venv` và mã Hermes Agent upstream dưới `$HOME/hermes-agent`. Có thể đặt `HERMES_HOME`, `HERMES_VENV` hoặc `HERMES_AGENT_DIR` trước khi cài để đổi đường dẫn mặc định.
- Installer thử chuẩn bị Hermes Agent và các gói phụ thuộc. Thiếu công cụ, lỗi mạng hoặc môi trường không tương thích có thể khiến một số bước bị bỏ qua kèm cảnh báo; hãy đọc kết quả và log trên máy.

Watchdog no-root là tùy chọn và chỉ quản lý tiến trình Hermes gateway do chính nó khởi chạy. Nó không quản lý Tailscale, web UI, DoH, trạng thái package Android, Doze hay Private DNS. Termux:Boot cũng là tùy chọn: installer không tự đăng ký hook khởi động.

### Bắt đầu

Chạy installer từ thư mục repo đã tải về:

```sh
sh ./install.sh
```

Với **Termux không root**, hãy tự cấu hình credential của provider và kênh Hermes trên máy, rồi khởi động và kiểm tra watchdog:

```sh
sh "$HOME/.hermes-home/scripts/no-root-watchdog.sh" start
sh "$HOME/.hermes-home/scripts/no-root-watchdog.sh" status
```

Muốn tự chạy sau khi reboot, cài và mở Termux:Boot một lần, sau đó chủ động đăng ký hook:

```sh
sh "$HOME/.hermes-home/scripts/termux-boot.sh" install
```

Xem [`docs/NO-ROOT.md`](docs/NO-ROOT.md) để biết đầy đủ cách chạy, dừng, gỡ hook và hoàn tác Shizuku. Với **root + Magisk**, luồng `service.d/` có hiệu lực sau khi khởi động lại máy.

Installer không tạo tài khoản provider hay cấp credential. Hãy lưu secret trên thiết bị, không lưu trong repo. Giá, gói miễn phí, hạn mức và model tùy thuộc provider; dự án không bảo đảm sử dụng miễn phí hoặc không giới hạn.

### “No Root, Like Root” có nghĩa gì — và không có nghĩa gì?

Helper Shizuku tùy chọn `scripts/shizuku-setup.sh` chỉ dùng cầu nối shell `rish` khi bạn gọi lệnh cụ thể. Helper hỗ trợ một số thao tác giới hạn với package bên thứ ba được chỉ rõ, mục Doze whitelist và Android Private DNS. Nó không cấp root, không có quyền `iptables`, và không triển khai DNS-over-HTTPS toàn hệ thống. Android Private DNS đổi cài đặt **toàn thiết bị** và dùng DNS-over-TLS (DoT), không phải DoH. Một số thao tác/quyền phụ thuộc phiên bản Android và hãng máy; hãy đọc trợ giúp lệnh và hiểu rõ thay đổi trước khi dùng.

### Giới hạn và lưu ý an toàn

- **Không bảo đảm 24/7:** quản lý pin của Android, giới hạn chạy nền của hãng, nhiệt độ, tình trạng pin, kết nối mạng và provider đều có thể làm gián đoạn. Wake lock có thể hao pin hơn nhưng vẫn không bảo đảm uptime.
- **Không tuyên bố đã xác minh no-root trên Android cho revision này:** kiểm tra cú pháp shell và mô phỏng hành vi không thay thế việc chạy trên thiết bị Android hoặc emulator thật.
- **Web UI:** không có xác thực. No-root mặc định chỉ bind `127.0.0.1`; muốn truy cập từ xa phải chủ động đặt `WEBUI_HOST`. Root vẫn mặc định bind `0.0.0.0`, tức nghe trên mọi giao diện mạng. Không mở UI không xác thực ra mạng không tin cậy hoặc Internet công cộng. Xem [`web/README.md`](web/README.md).
- **Helper chỉ dành cho root:** đổi `HERMES_HOME` hay khởi động Shizuku không làm các script Magisk trong `service.d/` chạy được trong Termux thông thường.
- **Tác động của script root:** xem kỹ `service.d/` trước khi dùng. `02-adbd.sh` đặt ADB-over-TCP ở cổng 5555 và khởi động lại `adbd`; tránh dùng trên mạng không tin cậy. `04-doh.sh` chạy proxy cục bộ và thêm quy tắc NAT `iptables` cần root. Đây là các tính năng riêng của luồng root, không phải helper Shizuku no-root.
- **Rủi ro lock cho preflight:** `scripts/preflight_venv.sh` hiện nội suy các dòng trong lock vào mã Python. Cho đến khi được sửa, không chạy script với lock không tin cậy hoặc lock mà tài khoản ít quyền có thể sửa, nhất là trong ngữ cảnh root/Magisk.
- **Secret và sao lưu:** không commit credential, dữ liệu phiên, cấu hình riêng tư hoặc log chưa che. Nếu thiếu công cụ/recipient mã hóa, `scripts/backup.sh` có thể để lại archive plaintext trên máy; không tải archive đó lên. Đọc [`docs/BACKUP.md`](docs/BACKUP.md) trước.

### Ghi chú dự án

- [Ghi chú thiết bị và báo cáo kiểm thử](docs/DEVICES.md) — phân biệt báo cáo của dự án với việc xác minh revision no-root này.
- [Hướng dẫn no-root, Termux:Boot và Shizuku](docs/NO-ROOT.md)
- [Hướng dẫn web UI](web/README.md)
- [Đóng góp](CONTRIBUTING.md)
- [Giấy phép](LICENSE)

`docs/demo-telegram.svg` là mockup minh họa, không phải ảnh chụp trực tiếp hay bằng chứng telemetry. Repo chưa có footage video thật hoặc MP4; nội dung TikTok trong [`docs/TIKTOK.md`](docs/TIKTOK.md) hiện chỉ là storyboard và kịch bản.
