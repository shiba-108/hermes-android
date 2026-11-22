# Rà soát bảo mật — hermes-android V2 no-root

## Kết luận

Rà soát tĩnh diff `2f19530..e46da08a417939efe0ee667e0637f99711fa7aff` cho thấy V2 thêm helper Shizuku được gọi tường minh, chứ không tự cấp quyền hoặc tự chạy lệnh hệ thống. Không xác nhận được shell injection trong các tham số package/hostname của helper. Tuy nhiên, đã xác nhận bằng kiểm tra cô lập rằng `scripts/preflight_venv.sh` có thể thực thi Python code đặt trong dữ liệu lock; tác động phụ thuộc ai kiểm soát lock và UID chạy preflight. Đây là điểm cần xử lý trước khi dùng lock không đáng tin với caller root.

Web UI không có xác thực. Launcher no-root mặc định chỉ bind loopback, nhưng root mode vẫn bind `0.0.0.0`; gọi thẳng `web/server.py` cũng mặc định bind mọi giao diện. Vì vậy, rủi ro mạng phụ thuộc cách khởi chạy và khả năng truy cập cổng, không phải lỗi chèn shell đã được xác nhận.

Các rủi ro root/Magisk đã có từ trước — đặc biệt chạy/nạp mã từ vùng Termux và installer không ghim nguồn — vẫn còn. Không có bộ test tự động trong cây target và không kiểm tra trên Android/Shizuku hay OnePlus 11R.

## Phạm vi và giới hạn

- Đối chiếu đúng diff từ `2f19530` tới target `feat/no-root` tại `e46da08a417939efe0ee667e0637f99711fa7aff`; 11 tệp thay đổi được rà soát cùng các tệp nền liên quan.
- Báo cáo này được cập nhật trên nhánh `fix/security`. `SECURITY.md` không nằm trong Git tree của commit nền hoặc target no-root, nên báo cáo này là thay đổi riêng trên nhánh bảo mật, không phải nội dung đã có trong commit V2.
- Đánh giá dựa trên mã nguồn và kiểm tra cục bộ. Không truy cập thiết bị Android, không chạy Shizuku, Magisk, installer hay kiểm thử mạng trên thiết bị. Báo cáo không chứa secret.

## Phát hiện và quyết định trước phát hành

### High — dữ liệu lock có thể trở thành Python code trong preflight

` scripts/preflight_venv.sh:38-50` đọc từng dòng lock, lấy `name`/`ver`, rồi nội suy trực tiếp chúng vào chuỗi Python ở dòng 49 (`m.version('$name') == '$ver'`). Một lock được tạo có chủ đích có thể thoát khỏi chuỗi và chạy biểu thức Python. Lock có thể được chọn qua `HERMES_LOCK` (`:21-22`) hoặc từ thư mục backup (`:23-27`). Các caller Magisk cũ gọi preflight từ `service.d/hermes.sh:10` và `service.d/05-watchdog.sh:23`; nếu lock mà caller root đọc được sửa bởi tác nhân có quyền thấp hơn, tác động có thể là thực thi code dưới UID root. Chưa xác minh quyền ghi của lock mặc định trên thiết bị; vì vậy đây là primitive đã xác nhận nhưng khả năng khai thác trong cấu hình mặc định còn phụ thuộc quyền sở hữu/quyền truy cập.

**Kiểm tra thực:** dùng bản `preflight_venv.sh` từ target, một lock giả và Python wrapper trong thư mục tạm cô lập; payload chỉ tạo một marker vô hại trong cùng thư mục. Marker được tạo và preflight thoát mã 0. Fixture đã được xóa sau thử nghiệm; không có thiết bị hay mạng tham gia.

**Khắc phục:** không dựng source code từ dữ liệu lock. Truyền tên/version thành đối số hoặc dữ liệu JSON, kiểm tra định dạng trước khi so sánh metadata, và xác minh owner/mode của lock trước mọi lần chạy dưới root. Không dùng biến môi trường trỏ tới lock do bên ít quyền hơn kiểm soát trong service root.

### High — Web UI không xác thực; mức phơi lộ phụ thuộc bind

`web/server.py:155-176` cung cấp endpoint không xác thực, gồm `POST /api/send`; nội dung được chuyển tới Hermes ở `web/server.py:104-118`. Đây là quyền gửi yêu cầu tới agent, không phải bằng chứng thực thi shell tùy ý: lệnh Hermes được gọi bằng argv (`subprocess.run`), không qua shell (`:107-111`).

` scripts/webui.sh:28-34` dùng `127.0.0.1` mặc định khi chạy no-root, nhưng root mode mặc định là `0.0.0.0`; `WEBUI_HOST` có thể ghi đè host. Nếu gọi trực tiếp `web/server.py`, mặc định của server tại `:181-185` vẫn là `0.0.0.0`. Do đó:

- Chỉ dùng cục bộ qua launcher no-root loopback: không có truy cập trực tiếp từ thiết bị mạng khác theo bind mặc định đó.
- Root mode, host override hoặc chạy trực tiếp server: không phát hành như một dịch vụ có thể truy cập từ mạng không tin cậy nếu chưa thêm xác thực và giới hạn mạng.
- Không chuyển tiếp cổng UI không xác thực ra Internet. Tailscale/IP riêng hoặc firewall là biện pháp giới hạn bề mặt, không thay thế xác thực.

### High — đường chạy Magisk vẫn tin cậy vùng Termux có thể ghi

`service.d/04-doh.sh:3-5` chạy `doh-proxy.py` từ thư mục home Termux; `service.d/05-watchdog.sh:5-10` có thể chạy lại script đó. `service.d/hermes.sh:5-7` và `service.d/05-watchdog.sh:18-22` đặt `PATH`, `LD_LIBRARY_PATH` và `LD_PRELOAD` trỏ vào thư mục Termux. Installer cài các service dưới quyền root khi phát hiện root + Magisk (`install.sh:83-99`). Nếu UID ứng dụng Termux sửa được script, binary hoặc thư viện được root nạp/chạy, lần boot/watchdog sau có thể thực thi mã thay thế với quyền cao.

**Blocker cho cấu hình Magisk/root:** không coi luồng này là an toàn để phát hành cho tới khi mã/thư viện chạy dưới root được đặt ở vùng chỉ root ghi được, kiểm tra owner/mode trước khi chạy và loại bỏ `LD_PRELOAD` từ Termux; ưu tiên chuyển service sang UID không đặc quyền. Không có `doh-proxy.py` trong target tree nên upstream, TLS và fallback của proxy không được đánh giá.

### High — nguồn installer đặc quyền chưa bất biến

README vẫn hướng dẫn `curl | bash`; `install.sh:31-37` clone nhánh repo thay vì một commit bất biến, và `install.sh:151-157` lấy Hermes agent mà không xác minh chữ ký/checksum. Khi luồng root/Magisk được dùng, thay đổi hoặc xâm nhập vào nguồn tải có thể được cài dưới quyền cao.

**Blocker cho installer đặc quyền:** trước phát hành cần ghim phiên bản/commit bất biến và xác minh chữ ký hoặc checksum qua kênh độc lập. Không khuyến nghị chạy installer root lấy trực tiếp từ nhánh thay đổi được.

### Shizuku — thao tác tường minh, quyền shell; không có Binder client riêng

` scripts/shizuku-setup.sh:2-4,33-39` mô tả helper tùy chọn và kiểm tra `rish -c id`; repo không tự triển khai Binder/client hay luồng xin/cấp quyền. Installer chỉ chép helper (`install.sh:104-116`), còn lệnh phải được người dùng gọi riêng. `scripts/no-root-watchdog.sh:1-2` nêu rõ watchdog no-root không gọi Shizuku. Không có fallback tự động sang root. Shizuku/rish cung cấp quyền shell khi được cấp quyền bên ngoài repo; đó không phải root.

`RISH_EXECUTABLE` hoặc `PATH` chọn binary rish (`:7-10`) mà không ghim danh tính/owner hay xác minh UID đầu ra. Nếu môi trường Termux đã bị cấu hình binary thay thế, helper có thể gọi binary đó; đây là rủi ro có điều kiện với executable/môi trường bị kiểm soát, không phải khai thác từ xa được xác nhận.

### Medium — package whitelist là đối chiếu chính xác, nhưng không phải danh sách cố định

` scripts/shizuku-setup.sh:41-57` giới hạn ký tự package và so khớp nguyên dòng với `pm list packages -3`. `pm disable` (`:77-80`) và `deviceidle add` (`:147-150`) chỉ nhận package bên thứ ba đã cài khớp chính xác; không có so khớp tiền tố hay lệnh hàng loạt. Tuy nhiên, phạm vi là **bất kỳ package bên thứ ba đã cài** do người dùng chỉ định, không phải allowlist cố định chỉ gồm Hermes/Termux. Ký tự shell như dấu cách, dấu chấm phẩy, quote và ký tự điều khiển bị loại; không thấy cơ sở để gọi các tham số này là shell injection.

Các bản ghi trong `$HM/shizuku-state` là tệp cục bộ dạng thường, không phải chứng cứ chống sửa giả mạo. `pm enable` dựa vào bản ghi đó (`:104-118`); nếu state bị sửa/corrupt, thao tác có thể không còn tương ứng với hành động của lần chạy này. Với `pm disable`, script lưu state trước lệnh nhưng xóa bản ghi khi lệnh lỗi hoặc hậu kiểm không xác nhận (`:86-100`); nếu kết quả thực tế không xác định, có thể mất thông tin hoàn tác. Chưa có bằng chứng các trường hợp lỗi này xảy ra trên Android.

### Medium — DeviceIdle: thao tác mới opt-in; cần giữ trạng thái khi kết quả không rõ

Helper Shizuku chỉ thêm/gỡ package cụ thể theo lệnh tường minh. Nó phân tích đầu ra `dumpsys deviceidle whitelist` bằng token (`scripts/shizuku-setup.sh:122-133`), không phải parser cấu trúc; chưa có bằng chứng đầu ra Android thực tế làm parser nhận nhầm. Khi truy vấn whitelist lỗi, một số nhánh biến lỗi thành output rỗng và có thể xóa state hoặc báo đã gỡ mà chưa xác minh (`:162-172,189-195`). Nên phân biệt trạng thái “không đọc được/chưa xác minh” với “package vắng” và giữ state cho tới khi hoàn tất xác nhận.

Hành vi root cũ khác với helper này: `service.d/03-nowake.sh:2` gọi `dumpsys deviceidle disable`, tức tắt DeviceIdle rộng hơn whitelist một package; file này không đổi trong diff V2.

### Medium — Private DNS là đổi DNS hệ thống qua DoT, không phải DoH

` scripts/shizuku-setup.sh:26-27,198-225` và `docs/NO-ROOT.md:45-47` phân biệt đúng Android Private DNS (DoT) với DoH. `private-dns set` là lệnh opt-in nhưng đổi cấu hình DNS toàn hệ thống. Bộ lọc hostname (`:47-50,206-231`) loại ký tự shell nhưng không kiểm tra đầy đủ độ dài hostname/nhãn hay quy tắc dấu gạch nối ở từng nhãn; đây là rủi ro cấu hình/khả dụng, không phải command injection đã xác nhận.

Lệnh ghi hostname và mode thành các bước riêng (`:222-231`); lỗi giữa chừng có thể để lại trạng thái áp dụng một phần. Nhánh restore cũng có thể không cho retry sau một lần khôi phục một phần (`:249-267`). Cần kiểm tra hậu điều kiện và giữ hướng dẫn khôi phục thủ công khi kết quả không chắc chắn.

## Các rủi ro nền còn nguyên

- **ADB TCP:** `service.d/02-adbd.sh:1-4` đặt cổng 5555 cả ở cấu hình thường lẫn `persist`, rồi khởi động lại adbd. Android còn có thể yêu cầu xác thực khóa ADB, nhưng listener TCP vẫn mở rộng bề mặt mạng. Nên chuyển sang opt-in rõ ràng trước phát hành Magisk.
- **Dependency integrity:** `install.sh:168-171` cài pip mới nhất; lock pin phiên bản nhưng không hash artifact. Nên pin pip và cân nhắc lock hash/`--require-hashes`; đây là cải thiện chuỗi cung ứng, không phải lỗ hổng runtime mới được xác nhận.
- **Root trust:** root/Magisk chỉ được cài khi UID root và Magisk phát hiện được (`install.sh:17-21,83-99`); điều đó không làm cho script/library từ vùng Termux trở nên đáng tin.
- Thay đổi `.gitignore` riêng trên nhánh `fix/security` bỏ qua `SOUL.md` (`.gitignore:23`); đây không phải thay đổi runtime của diff no-root.

## Kiểm tra đã chạy

- `sh -n` trên nội dung target của 7 script: `install.sh`, `scripts/backup.sh`, `scripts/no-root-watchdog.sh`, `scripts/preflight_venv.sh`, `scripts/shizuku-setup.sh`, `scripts/termux-boot.sh`, `scripts/webui.sh` — đạt.
- Phân tích cú pháp AST của `web/server.py` lấy từ target commit — đạt.
- `git diff --check 2f19530 e46da08a417939efe0ee667e0637f99711fa7aff` — đạt, không có whitespace lỗi.
- Kiểm tra cô lập lock giả cho `preflight_venv.sh` — xác nhận payload Python được thực thi; chỉ tạo marker trong thư mục tạm, đã xóa fixture.
- Không thấy đường dẫn bộ test/spec trong Git tree target. Không chạy installer, ứng dụng, lệnh Android/Shizuku, kiểm thử mạng hay OnePlus 11R.
