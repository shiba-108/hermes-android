# 📱 Thiết bị đã test & yêu cầu

Danh sách máy đã/đang chạy hermes-android. Nếu bạn cài thành công trên máy khác,
mở PR thêm một dòng vào đây (kèm RAM, Android version, cách root) — cực kỳ hữu ích
cho cộng đồng.

## ✅ Đã test chạy thật

| Máy | RAM | Android | Root | Ghi chú |
|---|---|---|---|---|
| **OnePlus 11R** | 16 GB | 16 (OxygenOS) | Magisk | Máy chính. Chạy 24/7, cắm sạc, watchdog ổn định. LD_PRELOAD libpython3.14. |

## 🧪 Đang thử nghiệm / cộng đồng báo chạy

| Máy | RAM | Android | Root | Ghi chú |
|---|---|---|---|---|
| **Google Pixel (4a/5/6/7)** | 6–8 GB | 12–14 | Magisk (patch boot.img) | Ổn định, ít bloat. Pixel 4a 6GB là bare-minimum dễ chịu. |
| **Samsung (S10/S20/A series)** | 6–8 GB | 12–14 | Magisk / KernelSU | Tắt bloat Samsung (One UI Home dup, Bixby). Knox không ảnh hưởng. |
| **Xiaomi / Redmi / POCO** | 6–8 GB | 12–14 | Magisk / KernelSU | Tắt MIUI optimization trong Settings → Battery. |

## 📋 Yêu cầu tối thiểu

| Thành phần | Tối thiểu | Khuyến nghị |
|---|---|---|
| Android | 12 | 13+ |
| RAM | 6 GB | 8–12 GB (OnePlus 11R: 16 GB) |
| Storage trống | 4 GB | 8 GB+ |
| Root | Magisk 25+ | Magisk mới nhất |
| Nguồn | Cắm sạc liên tục | Cắm sạc + `svc power stayon true` |
| Mạng | Wi-Fi ổn định | Wi-Fi + DoH (repo có sẵn) |

## 🔧 Root theo dòng máy

- **Pixel:** tải factory image → patch `boot.img` bằng Magisk app → flash qua fastboot.
- **OnePlus / Nothing:** unlock bootloader → flash `boot.img` đã patch.
- **Samsung:** dùng Odin + Magisk patch `AP_*.tar.md5` (tắt auto-reboot trong Odin).
- **Xiaomi:** unlock bootloader (chờ 7 ngày) → fastboot flash boot đã patch.
- **Không root được:** vẫn chạy được bằng Termux thuần — xem `install.sh` phần
  "Bỏ qua service.d". Bù lại phải tự chạy `nohup .../hermes gateway run &` và tự
  watchdog thủ công (Termux:Boot addon).

## ⚡ Mẹo theo RAM

- **6 GB:** đóng hết app nền (`pm disable-user` theo `BI-KIP.md` mục 6). Chọn bản Hermes nhẹ.
- **8 GB+:** thoải mái, có thể bật thêm web UI (`web/`) song song gateway.
- **12 GB+ (OnePlus 11R):** dư sức chạy cả gateway + webui + tailscale + doh cùng lúc.

## 🐛 Máy hay bị kill?

1. `dumpsys deviceidle whitelist + <pkg>` để whitelist Hermes.
2. Đảm bảo `03-nowake.sh` đã chạy: `settings get global stay_on_while_plugged_in` → phải là `3`.
3. Kiểm tra watchdog: `pgrep -f 05-watchdog` phải có PID.
4. Xem `logs/gateway.log` có dòng `Connected to Telegram` không.