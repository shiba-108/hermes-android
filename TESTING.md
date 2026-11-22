# Android 14 / API 34 emulator test status

**Kết luận: Android chưa được kiểm thử.** Sandbox không có `/dev/kvm`, `adb`, Android Emulator/SDK tools hoặc QEMU; lần thử boot TCG trước đó cũng không hoàn tất. Vì vậy không có căn cứ để xác nhận Termux trên Android 14/API 34, reboot, hay watchdog revive. Không có kiểm thử Android nào được đánh dấu PASS.

Không thao tác hoặc thay đổi OnePlus 11R. Không sử dụng API key hay model trả phí. Không tạo video: không có footage thật.

## Kiểm thử đã chạy trên Linux

Môi trường: Linux x86_64, nhánh `test/emulator`, base/HEAD `2f19530`, ngày 2026-11-22. Log chi tiết: [`test-logs/linux-host-2026-11-22.log`](test-logs/linux-host-2026-11-22.log).

| Kiểm tra | Kết quả | Phạm vi |
|---|---|---|
| `sh -n` cho `install.sh`, các script trong `scripts/` và `service.d/` | PASS (9 file) | Cú pháp shell trên Linux; không chứng minh chạy trên Android. |
| Parse AST cho các file Python | PASS (2 file) | Cú pháp Python; không cài dependency. |
| Chạy pipeline `curl | bash` hai lần từ HTTP server cục bộ | PASS | Installer chạy trên Linux với `HERMES_HOME` tạm; xác nhận file/lock/skill được chép và lần chạy lại tạo backup. Đã stub `venv/bin/python` nên **không** tải/cài Hermes hoặc package. Dùng bản checkout cục bộ, không dùng URL GitHub production. |
| Web UI `start`, `status`, `stop`; HTTP `GET /`, `/api/ping`, route không tồn tại | PASS | Smoke test trên Linux; gateway không chạy và `/api/ping` trả trạng thái down như mong đợi. Không phải kiểm thử watchdog. |

## Android 14 / API 34 — trạng thái từng mục

| Hạng mục | Trạng thái | Ghi chú |
|---|---|---|
| Boot AVD Android 14 / API 34 | BLOCKED | Không có KVM, emulator, SDK tools hay QEMU trong sandbox; TCG trước đó không boot xong. |
| Cài Termux no-root bằng `curl | bash` | NOT RUN | Chưa có Android/Termux để chạy. Pipeline host ở trên chỉ kiểm tra luồng cài file của installer, không phải Termux. |
| Reboot và xác nhận tự khởi động | NOT RUN | Không có Android emulator đang boot để reboot. |
| Kill process rồi xác nhận watchdog revive | NOT RUN | Watchdog Android không được thực thi; chỉ kiểm tra cú pháp script. |
| Telegram/gateway kết nối thật | NOT RUN | Không cấu hình secret, không gọi API hay model. |

## Lưu ý về chế độ không root

Tài liệu hiện có (`docs/DEVICES.md`, mục “Không root được”) nói người dùng Termux phải tự khởi chạy Hermes và tự cấu hình watchdog bằng Termux:Boot. `install.sh` chỉ bỏ qua `service.d` khi không có root/Magisk; nó không tự cài hoặc thiết lập job boot/watchdog cho Termux. Do đó, khi có thiết bị Android để chạy lại kiểm thử, cần xác định và ghi nhận cấu hình Termux:Boot/watchdog cụ thể trước khi đánh giá khả năng sống sót sau reboot.

## Tiêu chí hoàn tất Android

Chỉ đánh dấu PASS sau khi chạy trực tiếp trên Android 14/API 34 no-root Termux: ghi phiên bản Android/Termux, lệnh cài và kết quả, reboot thực tế, sau đó chủ động dừng process để quan sát watchdog khởi động lại và lưu log. Tạo video 30 giây chỉ khi có footage thật từ lần chạy đó.
