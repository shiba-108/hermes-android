# Rà soát bảo mật — hermes-android

## Tóm tắt

Có một đường truy cập mạng không xác thực tới web UI có thể chạy dưới quyền root trong cấu hình Magisk, cùng một số đường thực thi mã bên ngoài ranh giới tin cậy. Không phát hiện credential thực trong cây hiện tại hay Git history đã kiểm tra. Không tìm thấy `chmod 777` hoặc tham chiếu/quyền Shizuku. Đã bổ sung một rule `.gitignore` cho `SOUL.md`; không thay đổi installer hay luồng cài đặt.

## Phát hiện cần xử lý

### Critical (P0) — Web UI không xác thực, bind mọi giao diện và có thể chạy dưới quyền root

`web/server.py:179-185` mặc định bind `0.0.0.0`; `scripts/webui.sh:33-35` không truyền host khác. `service.d/05-watchdog.sh:26-30` tự khởi chạy web UI khi tệp server tồn tại, còn `install.sh:135-141` chép web UI vào thư mục cài đặt. Khi các script Magisk được cài và chạy, web server kế thừa UID của watchdog; không có bước hạ quyền. Endpoint `web/server.py:163-176` nhận thông điệp không cần đăng nhập rồi chuyển tiếp qua Hermes CLI tại `web/server.py:104-118`. Vì vậy máy trong LAN/Tailscale có thể gửi prompt tới agent; tùy các tool đã bật, hành động có thể được thực hiện trong ngữ cảnh quyền của tiến trình. Tài liệu cũng xác nhận web UI không có auth (`web/README.md:44-48`). Lệnh gọi CLI dùng danh sách argv, không dùng shell, nên đây không phải lỗi chèn lệnh shell trực tiếp; rủi ro chính là quyền truy cập agent không xác thực.

**Khắc phục:** không chạy web UI bằng root; mặc định bind `127.0.0.1` hoặc địa chỉ Tailscale cụ thể, không bind LAN công khai; thêm xác thực và ACL trước khi chuyển prompt; giới hạn kích thước request, tốc độ và thời gian xử lý. Không mở cổng 3000 ra Internet.

### High (P1) — Service root nạp/chạy mã từ vùng Termux có thể bị sửa bởi UID ứng dụng

`service.d/04-doh.sh:3-5` chạy Python với `/data/data/com.termux/files/home/doh-proxy.py`; `service.d/05-watchdog.sh:5-10` chạy lại cùng tệp. Tệp này không nằm trong repo. Đồng thời `service.d/hermes.sh:5-7` và `service.d/05-watchdog.sh:18-22` đặt `PATH`, `LD_LIBRARY_PATH` và `LD_PRELOAD` trỏ vào thư mục Termux. Các service được chép vào Magisk `service.d` khi installer chạy dưới root (`install.sh:63-75`). Nếu tiến trình/ứng dụng Termux có thể sửa script, thư viện hoặc binary ở các đường dẫn đó, service root có thể thực thi mã thay thế ở lần boot/watchdog kế tiếp.

**Khắc phục:** không chạy script hoặc nạp thư viện từ vùng ứng dụng có thể ghi dưới quyền root; chuyển Hermes/DoH sang UID không đặc quyền. Nếu cần helper root, đặt bản tối thiểu đã xác minh trong thư mục chỉ root ghi được, xác nhận owner/mode trước khi chạy, dùng môi trường sạch và đường dẫn tuyệt đối; bỏ `LD_PRELOAD` từ Termux khỏi tiến trình root.

### High (P1) — Installer tải nhánh thay đổi được và thực thi mà không xác minh tính toàn vẹn

README hướng dẫn `curl | bash` (`README.md:39,91,190`; cũng được ghi trong `install.sh:5`). Installer clone nhánh mặc định của repo (`install.sh:31-37`) và `hermes-agent` (`install.sh:151-157`) mà không ghim commit/tag hay xác minh chữ ký/checksum. Trong chế độ Magisk, các script được cài vào vùng service root. Vì vậy thay đổi hoặc xâm nhập vào nhánh tải có thể biến thành thực thi mã với quyền cao nhất trên thiết bị.

**Khắc phục:** phát hành theo phiên bản/commit bất biến, xác minh chữ ký hoặc checksum đã công bố qua kênh độc lập, và hướng dẫn tải–xem–xác minh trước khi chạy. Không dùng nhánh `main` làm nguồn cài đặt đặc quyền. Phát hiện này chỉ được ghi nhận; theo phạm vi yêu cầu, luồng installer không bị sửa.

### Medium (P2) — ADB TCP được bật dai dẳng dù được mô tả là tùy chọn

`service.d/02-adbd.sh:1-4` đặt cả `service.adb.tcp.port` và `persist.adb.tcp.port` thành `5555`, rồi khởi động lại `adbd`. `install.sh:63-75` cài mọi script trong `service.d` khi có root + Magisk; không có lựa chọn opt-in riêng. README gọi ADB là tùy chọn (`README.md:127`), nhưng script được cài mặc định theo điều kiện trên. Android có thể vẫn yêu cầu khóa xác thực ADB; tuy vậy listener TCP tồn tại và làm rộng bề mặt tấn công mạng.

**Khắc phục:** tắt ADB TCP mặc định; chỉ bật theo lựa chọn rõ ràng của chủ máy, giới hạn bằng firewall/interface riêng và tắt lại sau phiên bảo trì. Không ghi cấu hình port vào `persist` nếu không thật sự cần.

### Medium (P2) — Dependency pin theo phiên bản nhưng không khóa hash artifact

`install.sh:168-171` nâng pip lên phiên bản mới nhất rồi cài requirements. `scripts/preflight_venv.sh:31-37` có thể cài lại requirements khi lệch; `scripts/make_lock.py:43-56` sinh lock theo phiên bản, không kèm hash. Các lock hiện pin phiên bản phần lớn package, nhưng chưa xác minh rằng artifact tải về đúng nội dung đã duyệt.

**Khắc phục:** pin phiên bản pip; khi khả thi tạo lock có hash và cài với `--require-hashes`, hoặc xác minh checksum/chữ ký wheel trên nguồn tin cậy. Duy trì pin commit cho dependency Git và rà lại trước khi nâng phiên bản.

## Đã chỉnh trong nhánh này

- `.gitignore:23` hiện bỏ qua `SOUL.md`. Trước khi chỉnh, `git check-ignore` xác nhận tên này chưa bị bỏ qua; `scripts/backup.sh:26` lại đưa `SOUL.md` vào nhóm dữ liệu riêng tư cần sao lưu. Quy tắc mới ngăn thêm nhầm tệp này vào repo.
- Không sửa `install.sh` hay các service/luồng installer.

## Kết quả rà soát khác

- Secret scan trên cây hiện tại và toàn bộ Git history có sẵn (1 commit) không tìm thấy credential thực. Các kết quả gắn cờ là ví dụ placeholder trong README/installer, không phải secret đang dùng; không sao chép giá trị nào vào báo cáo.
- Không có rule hay lệnh `chmod 777`; installer chỉ đặt mode `755` cho script (`install.sh:73,94`).
- Không có mã, manifest hay tham chiếu Shizuku trong repo được rà soát. Quyền đặc biệt ở đây đến từ Magisk `service.d`, không phải Shizuku.
- Shell scripts qua `sh -n`; `scripts/make_lock.py` và `web/server.py` qua kiểm tra cú pháp Python. Đây là rà soát tĩnh: không chạy installer/app, không truy cập mạng hay thiết bị Android.
