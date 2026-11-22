# 📱 Thiết bị đã test & yêu cầu

Danh sách máy đã/đang chạy hermes-android. Nếu cài thành công trên máy khác,
mở PR thêm một dòng (RAM, Android, phương thức cài đặt) để giúp cộng đồng.

## ✅ Đã test chạy thật

| Máy | RAM | Android | Root | Ghi chú |
|---|---|---|---|---|
| **OnePlus 11R** | 16 GB | 16 (OxygenOS) | Magisk | Máy chính. Chạy 24/7, cắm sạc, watchdog ổn định. LD_PRELOAD libpython3.14. |

## 🧪 Đang thử nghiệm / cộng đồng báo chạy

| Máy | RAM | Android | Root | Ghi chú |
|---|---|---|---|---|
| **Google Pixel (4a/5/6/7)** | 6–8 GB | 12–14 | Magisk (patch boot.img) | Ổn định, ít bloat. Pixel 4a 6GB là bare-minimum dễ chịu. |
| **Samsung (S10/S20/A series)** | 6–8 GB | 12–14 | Magisk / KernelSU | Tắt bloat Samsung (heytap, Bixby…) chỉ sau khi đánh giá riêng. |
| **Xiaomi / Redmi / POCO** | 6–8 GB | 12–14 | Magisk / KernelSU | Hạn chế nền phụ thuộc phiên bản MIUI/HyperOS. |

## 📋 Yêu cầu tối thiểu

| Thành phần | Tối thiểu | Khuyến nghị |
|---|---|---|
| Android | 12 | 13+ |
| RAM | 6 GB | 8–12 GB |
| Storage trống | 4 GB | 8 GB+ |
| Root | Không bắt buộc | Magisk nếu cần `service.d` |
| Nguồn | Sạc ổn định | Cắm sạc; hành vi màn hình/Doze tùy cách cài |
| Mạng | Kết nối ổn định | Wi-Fi |

## Cài đặt root và no-root

- **Root + Magisk:** installer tiếp tục chép các script hiện có vào `service.d/`; reboot để nạp chúng. Một số script root thay đổi cài đặt hệ thống. Xem kỹ các file `service.d/` trước khi dùng.
- **Không root:** cài bằng Termux. Installer đặt dữ liệu trong thư mục người dùng và không tự bật boot hook, sửa package, Doze hoặc DNS. Watchdog no-root chỉ quản lý Hermes gateway. Termux:Boot và các thao tác Shizuku là tùy chọn, cần người dùng gọi riêng và có lệnh hoàn tác.
- Chi tiết, lệnh start/stop, quyền Shizuku và giới hạn DoH: [`NO-ROOT.md`](NO-ROOT.md).

## 🔧 Root theo dòng máy (nếu người dùng chủ động chọn root)

- **Pixel:** tải factory image → patch `boot.img` bằng Magisk app → flash qua fastboot.
- **OnePlus / Nothing:** unlock bootloader → flash `boot.img` đã patch.
- **Samsung:** dùng Odin + Magisk patch `AP_*.tar.md5` (tắt auto-reboot trong Odin).
- **Xiaomi:** unlock bootloader (chờ 7 ngày) → fastboot flash boot đã patch.

Root không bắt buộc để thử luồng Termux. Thực hiện root có thể xóa dữ liệu hoặc ảnh hưởng bảo hành; tự tìm hiểu rủi ro theo đúng thiết bị trước khi quyết định.

## ⚡ Mẹo theo RAM

- **6 GB:** đóng các ứng dụng không dùng; cân nhắc giới hạn số dịch vụ chạy đồng thời.
- **8 GB+:** có thể thử bật thêm web UI (`web/`) song song gateway.
- **12 GB+:** có thêm dư địa cho nhiều dịch vụ, nhưng mức ổn định vẫn tùy nhiệt độ, pin và chính sách nền.

## 🐛 Máy hay dừng ứng dụng nền?

1. Kiểm tra trạng thái bằng `sh "$HOME/.hermes-home/scripts/no-root-watchdog.sh" status`.
2. Android/OEM có thể giới hạn Termux ở nền; nếu cần, cân nhắc tự cài Termux:Boot và bỏ tối ưu pin bằng giao diện Android.
3. Shizuku có thể thêm package chính xác vào deviceidle whitelist theo lệnh riêng; xem [`NO-ROOT.md`](NO-ROOT.md). Không chạy lệnh package hàng loạt.
4. Xem `$HOME/.hermes-home/logs/gateway.log` và `no-root-watchdog.log`.

Các bước no-root không bảo đảm Android sẽ giữ ứng dụng chạy liên tục; kiểm thử trên thiết bị cụ thể trước khi dựa vào nó cho dịch vụ quan trọng.
