# Kết quả rà soát độc lập và kiểm thử host

## Kết luận

Đã rà mã ở commit `e46da08a417939efe0ee667e0637f99711fa7aff` (`feat/no-root`). Sáu nhóm kiểm thử host cục bộ đều đạt, nhưng chúng **không phải kiểm thử Android**. Rà soát phát hiện hai vấn đề mức P2 cần xử lý: Web UI bỏ qua `HERMES_VENV` tùy chỉnh khi gọi Hermes; và installer có thể kết thúc với mã 0 dù không có Python, không tạo được venv.

**Android 14/API 34 vẫn BLOCKED; mọi kiểm thử trên thiết bị Android là NOT RUN. Không có Android PASS nào được xác nhận.** Sandbox hiện không có `/dev/kvm`, `adb`, Android Emulator/SDK tools hoặc QEMU; lần thử boot TCG trước đó cũng không hoàn tất. Không thao tác OnePlus 11R, không dùng secret/API/model trả phí và không tạo video vì không có footage thật.

Log chi tiết: [`test-logs/review-feat-no-root-2026-11-22.log`](test-logs/review-feat-no-root-2026-11-22.log). Log của lượt kiểm tra trên base cũ `2f19530` được giữ riêng tại [`test-logs/linux-host-2026-11-22.log`](test-logs/linux-host-2026-11-22.log).

## Kiểm thử host

Môi trường: Linux x86_64. Mọi file và tiến trình harness được đặt trong thư mục tạm hoặc bind vào localhost; không tải/cài dependency, không gọi gateway/API thật.

| Nhóm | Kết quả | Phạm vi |
|---|---|---|
| Shell/Python syntax | PASS — `sh -n` cho 12 shell files; Python AST cho 2 file | Chỉ kiểm tra cú pháp trên Linux. |
| Installer | PASS | Chạy hai lượt với checkout cục bộ, `HERMES_HOME` tạm, giả lập uid không-root, Python/pip stub và thư mục agent tạo sẵn; kiểm tra chép file, backup khi chạy lại và nhánh no-root. Không clone repo, không tải package. |
| Termux:Boot | PASS | Kiểm tra từ chối ghi đè hook không do Hermes quản lý, cài và chạy lại idempotent, quyền config `0600`, gỡ hook/config do harness tạo. Chỉ dùng HOME tạm. |
| No-root watchdog | PASS | Start/status/stop với executable Hermes giả chạy cục bộ; không kết nối gateway thật. |
| Shizuku helper | PASS (mô phỏng) | Thử status, disable/enable package, chặn package hệ thống, Doze add/remove và Private DNS set/restore bằng `rish` giả với state tạm. Không gọi Shizuku/Android. |
| Web UI | PASS (smoke localhost) | Start/status/stop; `GET /` và `/api/ping` trả 200, route lạ trả 404; chỉ bind `127.0.0.1`, gateway down như kỳ vọng. |

### Phát hiện rà soát cần sửa

1. **P2 — Web UI không dùng venv tùy chỉnh để gọi Hermes.** `scripts/webui.sh` nhận và export `HERMES_VENV` (dòng 20–25, 71), nhưng `web/server.py` dựng `BIN` cố định từ thư mục cha của `HERMES_HOME` (dòng 27–29) rồi gọi executable đó khi xử lý `/api/send` (dòng 107–110). Tái hiện bằng hai executable giả cho thấy POST đã gọi binary mặc định suy ra từ `HERMES_HOME`, không gọi binary trong venv tùy chỉnh. Vì vậy UI có thể chạy nhưng gửi tin nhắn thất bại hoặc gọi nhầm Hermes khi dùng đường dẫn venv tùy chỉnh.

2. **P2 — Thiếu Python nhưng installer vẫn báo hoàn tất.** Khi không tìm được `python`/`python3`, `install.sh` bỏ qua tạo venv (dòng 188–212) nhưng vẫn in “Xong” và hướng dẫn chạy watchdog. Tái hiện với PATH không có Python: exit code là 0, không có venv/Hermes executable. Người dùng sau đó không thể khởi chạy watchdog. Luồng cài từ pipe cũng cần `git` để clone repo (dòng 52–56); yêu cầu này chưa nêu trong phần yêu cầu cài đặt.

Các phép tái hiện lỗi là kiểm thử host bổ sung, không làm thay đổi mã mục tiêu. Các điểm trên không được coi là PASS.

## Android 14 / API 34

| Hạng mục | Trạng thái | Ghi chú |
|---|---|---|
| Boot AVD Android 14 / API 34 | BLOCKED | Sandbox thiếu KVM, emulator, SDK tools và QEMU; lần boot TCG trước không hoàn tất. |
| Cài Termux no-root | NOT RUN | Không có Android/Termux để cài. Harness installer chỉ chạy trên Linux với stub. |
| Reboot và xác nhận tự khởi động | NOT RUN | Không có emulator Android đang boot. |
| Dừng process và xác nhận watchdog revive trên Android | NOT RUN | Harness watchdog dùng process giả trên Linux; không xác nhận hành vi Android. |
| Telegram/gateway kết nối thật | NOT RUN | Không cấu hình secret, không gọi API hay model. |

Chỉ đánh dấu PASS sau khi chạy trực tiếp trên Android 14/API 34 no-root Termux: ghi phiên bản Android/Termux và lệnh cài, reboot thực tế, chủ động dừng process để quan sát watchdog khởi động lại, rồi lưu log. Chỉ tạo video nếu có footage thật từ lần chạy Android đó.
