# hermes-android

## “No Root, Like Root” — a hook, not a promise

A small set of scripts and notes for running the [Hermes Agent](https://github.com/NousResearch/hermes-agent) gateway on Android.

> **Reality check:** this repository's boot-service path is for a rooted device with Magisk. The installer is **not currently a supported one-command setup for an ordinary, non-root Termux app**, and this project does not integrate with Shizuku. The no-root notes describe a manual, experimental Termux:Boot route only after Hermes already works in Termux.

[English](#english) · [Tiếng Việt](#tiếng-việt)

---

## English

### What this repository does

This repository contains an installer, Android service scripts, dependency lock files, backup helpers, and an optional small web chat UI for an existing Hermes Agent setup. It is a self-hosting experiment—not an Android compatibility guarantee, managed cloud service, or promise of continuous uptime.

The Magisk boot scripts attempt to start the gateway and run device/network helpers. The installer copies `service.d/` scripts only when it detects **both root and Magisk**. It also attempts to prepare the Hermes Agent directory and Python environment; some steps are skipped with a warning when required tools or directories are unavailable.

### Requirements and supported path

- A rooted Android device with Magisk for the repository's `service.d/` boot path.
- Network access and enough storage/RAM for Hermes Agent and its Python dependencies. Hardware needs vary by model and workload; the values in [`docs/DEVICES.md`](docs/DEVICES.md) are project notes, not guarantees.
- A configured Hermes Agent provider and any channel credentials you choose to use. Provider pricing, free tiers, quotas, and model availability can change; this repository does not enforce “free models only” or unlimited usage.

The device report currently identifies a OnePlus 11R as the project's real-device test entry. Other device rows are labelled as community/experimental notes. Do not assume that a device, Android version, or root method is verified just because it appears in a requirements table.

### Install notes

Review [`install.sh`](install.sh) before running it. Its defaults include `/data/local/hermes-home`, `/data/local/hermes-venv`, and `/data/local/hermes-agent`; `service.d/` scripts use Magisk/root-specific paths and commands. A plain Termux app normally cannot write those locations. Setting `HERMES_HOME` alone does not convert the hard-coded boot scripts into a rootless install.

The installer does **not** provision your provider account or create valid credentials. Configure Hermes Agent and its secrets locally, following the upstream project and your selected provider's instructions. Never commit tokens, private configuration, session data, or unredacted logs.

For an ordinary non-root Termux setup, read [`docs/NO-ROOT.md`](docs/NO-ROOT.md) first. That route is manual and is not an installer-supported deployment.

### What not to assume

- **No root equivalence:** Shizuku is not wired into this repository and does not turn its shell scripts into root scripts.
- **No guaranteed 24/7 service:** Android power management, OEM restrictions, network availability, thermal behavior, and external providers can interrupt operation.
- **No guaranteed self-healing:** the current gateway launcher writes to `/data/local/tmp/hermes.log`, while the watchdog checks `/data/local/hermes-home/logs/gateway.log`. Treat the watchdog as experimental; its current log-path mismatch means it is not reliable proof of gateway health or recovery.
- **Review optional network helpers:** `02-adbd.sh` attempts to enable ADB over TCP on port 5555; do not enable remote debugging on an untrusted network. `04-doh.sh` uses root-level `iptables` rules.
- **Web UI caution:** the web UI has no authentication. Keep it on a trusted LAN/Tailscale network and do not expose port 3000 directly to the public internet. See [`web/README.md`](web/README.md).
- **Backup caution:** `scripts/backup.sh` warns if encryption tools/recipients are missing, but can leave a plaintext archive locally. Read [`docs/BACKUP.md`](docs/BACKUP.md) before using remote backup options.

### Project notes

- [Device notes and current test report](docs/DEVICES.md)
- [Manual no-root notes: Termux:Boot and Shizuku](docs/NO-ROOT.md)
- [Backup guide](docs/BACKUP.md)
- [Web UI guide](web/README.md)
- [Contributing](CONTRIBUTING.md)
- [License](LICENSE)

The existing `docs/demo-telegram.svg` is an **illustrative mockup**, not a live capture or proof of reported telemetry. No real video footage is included with this repository.

---

## Tiếng Việt

### Repo này làm gì?

Repo này gồm installer, các script dịch vụ Android, file khóa phiên bản phụ thuộc, công cụ sao lưu và một web chat nhỏ tùy chọn cho bộ cài Hermes Agent có sẵn. Đây là thử nghiệm tự host — không phải cam kết tương thích mọi máy Android, dịch vụ cloud được quản lý hay bảo đảm chạy liên tục.

Các script boot dành cho Magisk cố gắng khởi chạy gateway và một số tác vụ hệ thống/mạng. Installer chỉ chép `service.d/` khi phát hiện **đồng thời có root và Magisk**. Installer cũng thử chuẩn bị thư mục Hermes Agent và môi trường Python; một số bước có thể bị bỏ qua kèm cảnh báo nếu thiếu công cụ hoặc thư mục phù hợp.

### Yêu cầu và đường chạy được hỗ trợ

- Máy Android đã root bằng Magisk để dùng đường khởi động `service.d/` của repo.
- Có mạng và đủ dung lượng/RAM cho Hermes Agent cùng các gói Python. Nhu cầu tùy thiết bị và tác vụ; số liệu trong [`docs/DEVICES.md`](docs/DEVICES.md) là ghi chú của dự án, không phải bảo đảm.
- Tự cấu hình provider cho Hermes Agent và thông tin đăng nhập của kênh bạn chọn. Giá, gói miễn phí, hạn mức và model của provider có thể thay đổi; repo này không ép dùng “model miễn phí” hay bảo đảm không giới hạn.

Danh sách thiết bị hiện ghi OnePlus 11R là mục đã chạy thực tế của dự án. Các dòng máy khác được đánh dấu là ghi chú cộng đồng/thử nghiệm. Đừng coi thiết bị, phiên bản Android hay phương thức root là đã xác minh chỉ vì chúng xuất hiện trong bảng yêu cầu.

### Lưu ý cài đặt

Hãy đọc [`install.sh`](install.sh) trước khi chạy. Mặc định script dùng các đường dẫn `/data/local/hermes-home`, `/data/local/hermes-venv` và `/data/local/hermes-agent`; các script trong `service.d/` dùng đường dẫn/lệnh dành cho Magisk và root. Ứng dụng Termux thông thường không có quyền ghi vào các vị trí đó. Chỉ đặt `HERMES_HOME` không biến các script boot hard-code thành bản cài không-root.

Installer **không** tạo tài khoản provider hoặc cấp thông tin đăng nhập hợp lệ. Hãy tự cấu hình Hermes Agent và lưu secret trên thiết bị theo hướng dẫn của dự án upstream và provider đã chọn. Không commit token, cấu hình riêng tư, dữ liệu phiên hoặc log chưa che thông tin nhạy cảm.

Nếu dùng Termux thông thường không root, hãy đọc [`docs/NO-ROOT.md`](docs/NO-ROOT.md) trước. Đây là lộ trình thủ công và hiện chưa được installer hỗ trợ.

### Những điều không nên mặc định

- **Không tương đương root:** repo chưa tích hợp Shizuku; Shizuku không biến các shell script này thành script có quyền root.
- **Không bảo đảm chạy 24/7:** quản lý pin của Android, giới hạn riêng của hãng, mạng, nhiệt độ và dịch vụ bên ngoài đều có thể làm gián đoạn.
- **Không bảo đảm tự phục hồi:** launcher hiện ghi log gateway vào `/data/local/tmp/hermes.log`, trong khi watchdog kiểm tra `/data/local/hermes-home/logs/gateway.log`. Hãy xem watchdog là thử nghiệm; lệch đường dẫn log khiến nó không phải bằng chứng đáng tin cậy về trạng thái hay khả năng khôi phục gateway.
- **Xem kỹ helper mạng tùy chọn:** `02-adbd.sh` thử bật ADB qua TCP ở cổng 5555; không bật gỡ lỗi từ xa trên mạng không tin cậy. `04-doh.sh` dùng quy tắc `iptables` cần root.
- **Lưu ý web UI:** web UI không có xác thực. Chỉ dùng trong LAN/Tailscale đáng tin cậy; không mở trực tiếp cổng 3000 ra Internet công cộng. Xem [`web/README.md`](web/README.md).
- **Lưu ý sao lưu:** nếu thiếu công cụ/địa chỉ mã hóa, `scripts/backup.sh` có cảnh báo nhưng vẫn có thể để lại archive chưa mã hóa trên máy. Đọc [`docs/BACKUP.md`](docs/BACKUP.md) trước khi dùng tùy chọn sao lưu từ xa.

### Ghi chú dự án

- [Ghi chú thiết bị và báo cáo test hiện có](docs/DEVICES.md)
- [Hướng dẫn thủ công không root: Termux:Boot và Shizuku](docs/NO-ROOT.md)
- [Hướng dẫn sao lưu](docs/BACKUP.md)
- [Hướng dẫn web UI](web/README.md)
- [Đóng góp](CONTRIBUTING.md)
- [Giấy phép](LICENSE)

Tệp `docs/demo-telegram.svg` hiện có là **mockup minh họa**, không phải ảnh chụp trực tiếp hay bằng chứng cho số liệu telemetry. Repo chưa có footage video thật.
