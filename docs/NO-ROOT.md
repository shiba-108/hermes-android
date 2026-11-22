# No-root on Android: Termux:Boot and Shizuku

## The short answer

**“No Root, Like Root” is a hook, not a claim of root-level access.** The current `hermes-android` installer is not a supported one-command install for a regular, non-root Termux app. Its default directories are under `/data/local/...`, and its boot scripts depend on Magisk/root. The repository has no Shizuku API integration.

A manual Termux setup may be possible if you first install and configure Hermes Agent in Termux by its own instructions. Termux:Boot can then ask Termux to start a command after boot. This does not grant root, does not make the repository's Magisk scripts work, and has not been verified here on a physical Android device.

## What each option can and cannot do

| Option | What it can do | What it does not do for this repository |
|---|---|---|
| **Termux:Boot** | Run scripts inside the Termux app after Android boots, once the add-on is installed and opened. | Does not grant root or make `/data/adb/service.d/`, `iptables`, `setprop`, or other privileged operations available. It does not install Hermes Agent for this repo. |
| **Shizuku via wireless debugging** | Let compatible Android apps use supported system APIs through a Shizuku server started with ADB-level privileges. | This repo is shell scripts, not a Shizuku-integrated Android app. Shizuku does not make these scripts root, and the wireless-debugging server must be started again after reboot on Android 11+. |
| **Shizuku started with root** | Start Shizuku on a rooted device. | Still does not add Shizuku support to this repository; use the documented Magisk path if you already have root. |

Shizuku's ADB-backed permissions are limited and can vary across Android versions and manufacturers. See the [official setup guide](https://shizuku.rikka.app/guide/setup/) and [Shizuku project notes](https://github.com/RikkaApps/Shizuku). Termux:Boot's official instructions are in the [Termux:Boot README](https://github.com/termux/termux-boot#how-to-use).

## Manual Termux:Boot template

This is a **generic startup template**, not an installer or a tested hermes-android feature. Use it only after `hermes gateway run` works interactively in your Termux session and you have followed the [Hermes Agent instructions](https://github.com/NousResearch/hermes-agent) to install and configure the CLI there.

1. Install Termux and the Termux:Boot add-on from compatible signing sources. Do not mix app/add-on sources with different signing keys. Open Termux:Boot once from its launcher.
2. In Termux, verify that `hermes` is on the command path (`command -v hermes`) and that you can start the gateway manually. Configure provider/channel credentials locally using the upstream instructions; never put actual credentials in this repository or in a public video.
3. Create the boot script below. It starts the already-installed CLI in the Termux user context and writes a private local log. If your manual setup needs environment variables or a different CLI path, configure those locally in the script or Termux profile; do not copy secrets into tracked project files.

```sh
mkdir -p ~/.termux/boot
cat > ~/.termux/boot/start-hermes <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh
set -eu
umask 077

# Optional: helps keep the CPU awake; it is not a guarantee against OEM kills.
if command -v termux-wake-lock >/dev/null 2>&1; then
  termux-wake-lock || true
fi

sleep 10
command -v hermes >/dev/null 2>&1 || exit 127
mkdir -p "$HOME/.local/state/hermes"
nohup hermes gateway run \
  >> "$HOME/.local/state/hermes/gateway.log" 2>&1 \
  </dev/null &
EOF
chmod 700 ~/.termux/boot/start-hermes
```

4. Reboot the phone, unlock it if your device requires that, then inspect the local log at `~/.local/state/hermes/gateway.log` and confirm the gateway/channel actually became available. Do not treat a shell process existing as proof that the Telegram connection or model call works.
5. If Android or the phone manufacturer stops Termux in the background, review that device's battery/background settings and test again. A wake lock, Termux:Boot, or Shizuku cannot guarantee 24/7 uptime, network access, or successful provider requests.

Termux:Boot runs scripts from `~/.termux/boot/` in sorted order and recommends launching its app once after install. Its documentation also mentions `termux-wake-lock` as an optional first action. Exact background behavior depends on the Android build and manufacturer.

## Why the repository installer is not the no-root setup

The current `install.sh` defaults include `/data/local/hermes-home`, `/data/local/hermes-venv`, and `/data/local/hermes-agent`. In a normal Termux app those are not the app's writable home. `service.d/` is copied only when the installer detects both root and Magisk, and the service scripts themselves use root/Magisk paths and commands. This guide does not claim that changing `HERMES_HOME` alone fixes those assumptions.

The repository also has no Android app component that calls the Shizuku API. Starting Shizuku does not satisfy the root checks in `install.sh` or provide automatic access to the repository's root-only operations.

## Sources

- [Termux:Boot official README](https://github.com/termux/termux-boot/blob/master/README.md)
- [Shizuku official setup guide](https://shizuku.rikka.app/guide/setup/)
- [Shizuku official repository and permission notes](https://github.com/RikkaApps/Shizuku)
- [Hermes Agent upstream repository](https://github.com/NousResearch/hermes-agent)

---

# Android không root: Termux:Boot và Shizuku

## Tóm tắt

**“No Root, Like Root” là câu hook, không phải tuyên bố có quyền root.** Installer `hermes-android` hiện chưa phải cách cài một lệnh được hỗ trợ cho ứng dụng Termux thông thường không root. Đường dẫn mặc định nằm dưới `/data/local/...`, còn script khởi động cần Magisk/root. Repo chưa tích hợp API Shizuku.

Có thể thử cấu hình Termux thủ công nếu bạn cài và cấu hình Hermes Agent trong Termux theo hướng dẫn riêng của dự án đó trước. Sau đó Termux:Boot có thể yêu cầu Termux chạy lệnh sau khi Android khởi động. Cách này không cấp root, không làm các script Magisk của repo hoạt động và chưa được xác minh trên thiết bị Android thật trong phiên làm việc này.

## Mỗi lựa chọn làm được gì — và không làm được gì

| Lựa chọn | Có thể làm gì | Không làm được gì cho repo này |
|---|---|---|
| **Termux:Boot** | Chạy script trong ứng dụng Termux sau khi Android boot, sau khi cài và mở add-on. | Không cấp root, không mở quyền vào `/data/adb/service.d/`, `iptables`, `setprop` hay thao tác đặc quyền khác. Không tự cài Hermes Agent cho repo này. |
| **Shizuku qua wireless debugging** | Cho ứng dụng Android tương thích gọi một số system API qua Shizuku server được khởi động bằng quyền ADB. | Repo này là shell script, không phải ứng dụng Android đã tích hợp Shizuku. Shizuku không biến các script thành script root; trên Android 11+, server qua wireless debugging phải được khởi động lại sau mỗi lần reboot. |
| **Shizuku khởi động bằng root** | Khởi động Shizuku trên máy đã root. | Vẫn không bổ sung hỗ trợ Shizuku vào repo; nếu đã root thì dùng đường Magisk được tài liệu hóa. |

Quyền ADB của Shizuku có giới hạn và có thể khác nhau theo phiên bản Android/hãng máy. Xem [hướng dẫn setup chính thức](https://shizuku.rikka.app/guide/setup/) và [ghi chú dự án Shizuku](https://github.com/RikkaApps/Shizuku). Hướng dẫn Termux:Boot chính thức nằm trong [README Termux:Boot](https://github.com/termux/termux-boot#how-to-use).

## Mẫu khởi chạy thủ công bằng Termux:Boot

Đây là **mẫu khởi chạy chung**, không phải installer hay tính năng `hermes-android` đã được kiểm thử. Chỉ dùng sau khi lệnh `hermes gateway run` chạy được trong phiên Termux của bạn và bạn đã cài/cấu hình CLI theo [hướng dẫn Hermes Agent](https://github.com/NousResearch/hermes-agent).

1. Cài Termux và add-on Termux:Boot từ nguồn có cùng chữ ký tương thích. Không trộn nguồn cài ứng dụng/add-on dùng khóa ký khác nhau. Mở Termux:Boot một lần từ màn hình ứng dụng.
2. Trong Termux, kiểm tra `hermes` có trên PATH (`command -v hermes`) và chạy gateway thủ công được. Cấu hình credential provider/kênh riêng trên máy theo hướng dẫn upstream; tuyệt đối không chép credential thật vào repo hoặc video công khai.
3. Tạo script boot bên dưới. Script chạy CLI đã cài trong quyền người dùng Termux và ghi log cục bộ với quyền hạn chế. Nếu cách cài thủ công của bạn cần biến môi trường hoặc đường dẫn CLI khác, cấu hình riêng trên máy/Termux; không đưa secret vào file được theo dõi trong repo.

```sh
mkdir -p ~/.termux/boot
cat > ~/.termux/boot/start-hermes <<'EOF'
#!/data/data/com.termux/files/usr/bin/sh
set -eu
umask 077

# Tùy chọn: giúp giữ CPU thức; không bảo đảm hãng máy sẽ không kill app.
if command -v termux-wake-lock >/dev/null 2>&1; then
  termux-wake-lock || true
fi

sleep 10
command -v hermes >/dev/null 2>&1 || exit 127
mkdir -p "$HOME/.local/state/hermes"
nohup hermes gateway run \
  >> "$HOME/.local/state/hermes/gateway.log" 2>&1 \
  </dev/null &
EOF
chmod 700 ~/.termux/boot/start-hermes
```

4. Reboot điện thoại, mở khóa nếu thiết bị yêu cầu, rồi kiểm tra log cục bộ ở `~/.local/state/hermes/gateway.log` và xác minh gateway/kênh thực sự hoạt động. Chỉ thấy tiến trình shell còn sống không chứng minh Telegram đã kết nối hay model gọi được.
5. Nếu Android hoặc hãng máy dừng Termux chạy nền, xem lại thiết lập pin/chạy nền riêng cho thiết bị rồi thử lại. Wake lock, Termux:Boot hay Shizuku đều không bảo đảm uptime 24/7, kết nối mạng hoặc yêu cầu provider thành công.

Termux:Boot chạy các script trong `~/.termux/boot/` theo thứ tự tên và khuyến nghị mở ứng dụng một lần sau khi cài. Tài liệu cũng nêu `termux-wake-lock` là hành động đầu tùy chọn. Hành vi chạy nền chính xác phụ thuộc bản Android và hãng máy.

## Vì sao installer của repo chưa phải đường cài không-root

`install.sh` hiện mặc định dùng `/data/local/hermes-home`, `/data/local/hermes-venv` và `/data/local/hermes-agent`. Ứng dụng Termux thông thường không có quyền ghi vào các vị trí đó vì thư mục dữ liệu của nó riêng biệt. `service.d/` chỉ được chép khi installer phát hiện đồng thời root và Magisk; các script dịch vụ cũng dùng đường dẫn/lệnh root/Magisk. Tài liệu này không khẳng định chỉ cần đổi `HERMES_HOME` là sửa được các giả định đó.

Repo cũng không có thành phần ứng dụng Android gọi API Shizuku. Khởi động Shizuku không đáp ứng kiểm tra root của `install.sh` và không tự cấp quyền cho thao tác chỉ dành cho root trong repo.

## Nguồn

- [README Termux:Boot chính thức](https://github.com/termux/termux-boot/blob/master/README.md)
- [Hướng dẫn Shizuku chính thức](https://shizuku.rikka.app/guide/setup/)
- [Repo Shizuku chính thức và ghi chú về quyền](https://github.com/RikkaApps/Shizuku)
- [Repo Hermes Agent upstream](https://github.com/NousResearch/hermes-agent)
