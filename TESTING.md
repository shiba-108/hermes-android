# Kết quả kiểm thử host và trạng thái Android 14

## Kết luận mới nhất

Code được kiểm tra: `5622132f261aff804b3d798d8bab74dc038a3045` (`feat/no-root`). Trên Linux x86_64, toàn bộ 8 test trong `tests/no_root_harness.py` đạt. Đây là kiểm thử host với stub, thư mục tạm và localhost; không phải kiểm thử Android.

Regression bảo mật tạo một tên package trong lock có chứa payload benign chỉ chạm một marker trong thư mục tạm nếu bị Python evaluate. Trên commit mới, marker không xuất hiện và test đạt. Negative control chạy đúng test ấy trên code cũ `e46da08a417939efe0ee667e0637f99711fa7aff` thất bại như mong đợi vì marker đã bị tạo, xác nhận regression bắt được lỗi cũ.

Các vấn đề P2 được nêu trong lần rà soát trước đã được xử lý trong `5622132`: kiểm tra phiên bản package truyền tên/version qua argv thay vì nhúng dữ liệu lock vào Python source; Web UI gọi Hermes từ `HERMES_VENV` tùy chỉnh; installer dừng với lỗi nếu thiếu Python hoặc thiếu Git khi cần clone. Các test host xác nhận các luồng này bằng fixture/mock, không chạy cài package thật.

**Android 14/API 34 vẫn BLOCKED; kiểm thử trên Android/Termux là NOT RUN. Không có Android PASS nào được xác nhận.** Sandbox không có `/dev/kvm`, `adb`, Android Emulator/SDK tools hoặc QEMU; lần thử boot TCG trước đó không hoàn tất. Không thao tác OnePlus 11R, không dùng secret/API/model trả phí.

Log cập nhật: [`test-logs/review-feat-no-root-2026-11-22.log`](test-logs/review-feat-no-root-2026-11-22.log). Kết quả rà soát và host test trước đó trên commit `e46da08` vẫn được giữ ở phần đầu log; log nền cũ `2f19530` nằm tại [`test-logs/linux-host-2026-11-22.log`](test-logs/linux-host-2026-11-22.log).

## Phạm vi chạy trên host

Lệnh chính: `python3 tests/no_root_harness.py` — **8/8 test đạt**.

| Kiểm tra | Kết quả | Phạm vi |
|---|---|---|
| Shell/Python syntax | PASS | `sh -n` cho shell files trong harness và compile Python của Web UI; chỉ xác nhận cú pháp trên Linux. |
| Lock package-name marker payload | PASS | Dữ liệu package không bị evaluate; chỉ tạo marker trong temp nếu bị thực thi. Venv Python được harness cung cấp, metadata giả; không cài package. |
| Negative control trên `e46da08` | EXPECTED FAIL | Cùng test thấy marker bị tạo trên bản cũ; đây là kiểm tra hiệu lực của regression, không phải lỗi ở commit mới. |
| Root lock trust boundary | PASS | Giả lập uid 0; lock path không đáng tin bị từ chối fail-closed. Không thay đổi quyền hay file hệ thống. |
| Installer thiếu Python / Git | PASS | Chạy với PATH và HOME tạm; xác nhận installer dừng trước khi báo hoàn tất/ghi file. Không clone hay tải dependency. |
| Web UI và venv tùy chỉnh | PASS | Stub Hermes/Python, server bind localhost; kiểm tra endpoint và đúng executable của custom venv. Không kết nối gateway/API thật. |
| Mặc định host/loopback | PASS | Kiểm tra chọn bind host cho root/non-root bằng mock. |

Môi trường: Linux x86_64, uid 1000. Các luồng tích hợp chỉ dùng file tạm và localhost; không gọi dịch vụ ngoài, không dùng secret và không tải/cài dependency.

## Android 14 / API 34

| Hạng mục | Trạng thái | Ghi chú |
|---|---|---|
| Boot AVD Android 14 / API 34 | BLOCKED | Sandbox thiếu KVM, emulator, SDK tools và QEMU; lần boot TCG trước không hoàn tất. |
| Cài Termux no-root | NOT RUN | Không có Android/Termux để cài. Harness installer chỉ chạy host với stub. |
| Reboot và xác nhận tự khởi động | NOT RUN | Không có emulator Android đang boot. |
| Dừng process và xác nhận watchdog revive trên Android | NOT RUN | Không xác nhận hành vi trên Android. |
| Telegram/gateway kết nối thật | NOT RUN | Không cấu hình secret, không gọi API hay model. |

Chỉ đánh dấu PASS sau khi chạy trực tiếp trên Android 14/API 34 no-root Termux, ghi phiên bản Android/Termux và lệnh cài, reboot thực tế, chủ động dừng process để quan sát watchdog khởi động lại, rồi lưu log. Không có video nào được tạo.
