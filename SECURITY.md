# Rà soát bảo mật — hermes-android V2 no-root

## Kết luận

Rà soát bổ sung diff `e46da08..5622132` xác nhận lỗi chèn Python từ tên package/version trong lock đã được khắc phục: preflight truyền chúng thành đối số, không ghép vào source Python. Khi chạy dưới UID 0, preflight còn từ chối lock nếu file hoặc bất kỳ thư mục cha nào không thuộc root hay có quyền ghi group/other. Harness cô lập xác nhận payload không còn chạy và lock path không tin cậy bị từ chối.

Web UI vẫn không có xác thực. Trước `5622132`, gọi trực tiếp `web/server.py` mặc định bind mọi giao diện; sau vá, mặc định trực tiếp là loopback khi non-root nhưng vẫn là `0.0.0.0` khi root. Launcher giữ mặc định loopback cho no-root và mọi giao diện cho root; `WEBUI_HOST` ở launcher hoặc `--host` khi gọi server trực tiếp có thể mở rộng bind.

Các rủi ro root/Magisk có từ trước — đặc biệt chạy/nạp mã từ vùng Termux và installer không ghim nguồn — vẫn còn. Installer nay dừng sớm khi thiếu Python/git cần thiết hoặc clone hermes-agent thất bại, nhưng lỗi tạo venv/pip vẫn có nhánh cảnh báo và không phải mọi lỗi đều làm installer dừng. Target có harness 8 ca; toàn bộ pass trên host. Không kiểm tra trên Android/Shizuku hay OnePlus 11R.

## Phạm vi và giới hạn

- Đối chiếu diff `e46da08..5622132` (5 tệp thay đổi) và các tệp liên quan; giữ lại kết quả rà soát lịch sử `2f19530..e46da08a417939efe0ee667e0637f99711fa7aff` bên dưới.
- Báo cáo này được cập nhật trên nhánh `fix/security`. `SECURITY.md` không nằm trong Git tree của commit nền hoặc target no-root, nên báo cáo này là thay đổi riêng trên nhánh bảo mật, không phải nội dung đã có trong commit V2.
- Đánh giá dựa trên mã nguồn và kiểm tra cục bộ trong worktree tạm tại `5622132`; harness chỉ dùng fixture tạm và HTTP loopback. Không truy cập thiết bị Android/OnePlus 11R, không chạy Shizuku/Magisk hay installer lên thiết bị, không kiểm thử mạng trên thiết bị. Báo cáo không chứa secret.

## Phát hiện và quyết định trước phát hành

### High trước vá — dữ liệu lock có thể trở thành Python code trong preflight (đã khắc phục ở `5622132`)

Ở snapshot `e46da08`, `scripts/preflight_venv.sh:45-49` lấy `name`/`ver` từ lock rồi nội suy trực tiếp vào chuỗi Python (`m.version('$name') == '$ver'`). Lock được tạo có chủ đích có thể thoát chuỗi và chạy Python. Lock được chọn qua `HERMES_LOCK` hoặc từ thư mục backup; caller Magisk cũ gọi preflight từ `service.d/hermes.sh` và `service.d/05-watchdog.sh`. Nếu caller root đọc lock do tác nhân ít quyền hơn sửa được, tác động có thể là thực thi code dưới UID root. Khả năng khai thác trong cấu hình mặc định phụ thuộc quyền sở hữu/quyền truy cập lock trên thiết bị.

**Kiểm tra trước vá:** thử nghiệm cô lập trên bản `e46da08` với lock giả và Python wrapper tạo marker trong thư mục tạm đã xác nhận payload chạy; preflight thoát mã 0. Đây là kết quả của bản cũ, không phải trạng thái hiện tại.

**Sau vá:** `5622132:scripts/preflight_venv.sh:85` truyền tên/version bằng `sys.argv`, loại bỏ nội suy dữ liệu lock vào source Python. Chỉ khi UID là 0, guard tại dòng 40–71 dùng `os.path.abspath` và `os.lstat` duyệt từ lock tới `/`; lock phải là regular file, mọi component cha phải là directory, và tất cả phải có `st_uid == 0` đồng thời không có bit `S_IWGRP` hoặc `S_IWOTH`. Bất kỳ lỗi kiểm tra nào đều ghi `LOCK TRUST FAILURE` và thoát trước vòng đọc package/install. Harness target xác nhận payload không tạo marker và đường dẫn lock không tin cậy bị fail-closed.

Guard xác lập trust boundary cho đường dẫn lock, không xác minh tính toàn vẹn của Python/venv được chạy, package artifacts hay toàn bộ dependency supply chain. Những rủi ro này vẫn thuộc các phát hiện root trust/dependency integrity bên dưới; trên thiết bị chưa xác minh được owner/mode thực tế của các đường dẫn Android.

### High — Web UI không xác thực; mức phơi lộ phụ thuộc bind

`web/server.py:155-176` cung cấp endpoint không xác thực, gồm `POST /api/send`; nội dung được chuyển tới Hermes ở `web/server.py:104-118`. Đây là quyền gửi yêu cầu tới agent, không phải bằng chứng thực thi shell tùy ý: lệnh Hermes được gọi bằng argv (`subprocess.run`), không qua shell (`:107-111`).

Trước `5622132`, gọi trực tiếp `web/server.py` mặc định là `0.0.0.0`. Sau vá, `web/server.py:179-190` chọn `0.0.0.0` khi root và `127.0.0.1` khi non-root. Launcher `scripts/webui.sh:27-34,71-72` truyền host tường minh: no-root mặc định loopback, root mặc định mọi giao diện; `WEBUI_HOST` có thể ghi đè. Gọi server trực tiếp có thể ghi đè bằng đối số `--host`.

- Chỉ dùng cục bộ qua launcher no-root loopback: không có truy cập trực tiếp từ thiết bị mạng khác theo bind mặc định đó.
- Root mode, `WEBUI_HOST`/`--host` mở rộng bind, hoặc gọi trực tiếp server dưới root: không phát hành như một dịch vụ có thể truy cập từ mạng không tin cậy nếu chưa thêm xác thực và giới hạn mạng.
- Không chuyển tiếp cổng UI không xác thực ra Internet. Tailscale/IP riêng hoặc firewall là biện pháp giới hạn bề mặt, không thay thế xác thực.

### Installer và custom venv — cải thiện hành vi, không đóng các rủi ro nguồn tải

`install.sh` nay kiểm tra Python sớm và thoát nếu thiếu; kiểm tra git khi cần clone agent và thoát với lỗi nếu clone thất bại (`install.sh:30-34,79-82,186-196`). Đây là fail-fast cho các prerequisite/clone này, không phải cam kết mọi lỗi đều dừng: tạo venv và pip install vẫn có nhánh cảnh báo rồi tiếp tục (`:202-224`). `HERMES_VENV` được truyền qua launcher và dùng để chọn Hermes CLI trong `web/server.py`; harness xác nhận custom Hermes stub được gọi thay vì venv mặc định. Việc này không ghim commit hay xác minh nguồn tải, nên phát hiện nguồn installer đặc quyền chưa bất biến bên dưới vẫn còn.

### High — đường chạy Magisk vẫn tin cậy vùng Termux có thể ghi

`service.d/04-doh.sh:3-5` chạy `doh-proxy.py` từ thư mục home Termux; `service.d/05-watchdog.sh:5-10` có thể chạy lại script đó. `service.d/hermes.sh:5-7` và `service.d/05-watchdog.sh:18-22` đặt `PATH`, `LD_LIBRARY_PATH` và `LD_PRELOAD` trỏ vào thư mục Termux. Installer chép service dưới quyền root khi phát hiện root + Magisk (`install.sh:103-118`). Nếu UID ứng dụng Termux sửa được script, binary hoặc thư viện được root nạp/chạy, lần boot/watchdog sau có thể thực thi mã thay thế với quyền cao.

**Blocker cho cấu hình Magisk/root:** không coi luồng này là an toàn để phát hành cho tới khi mã/thư viện chạy dưới root được đặt ở vùng chỉ root ghi được, kiểm tra owner/mode trước khi chạy và loại bỏ `LD_PRELOAD` từ Termux; ưu tiên chuyển service sang UID không đặc quyền. Không có `doh-proxy.py` trong target tree nên upstream, TLS và fallback của proxy không được đánh giá.

### High — nguồn installer đặc quyền chưa bất biến

README vẫn hướng dẫn `curl | bash`; `install.sh:57-62` clone repo không ghim commit, và `install.sh:189-196` lấy Hermes agent mà không xác minh chữ ký/checksum. Khi luồng root/Magisk được dùng, thay đổi hoặc xâm nhập vào nguồn tải có thể được cài dưới quyền cao.

**Blocker cho installer đặc quyền:** trước phát hành cần ghim phiên bản/commit bất biến và xác minh chữ ký hoặc checksum qua kênh độc lập. Không khuyến nghị chạy installer root lấy trực tiếp từ nhánh thay đổi được.

### Shizuku — thao tác tường minh, quyền shell; không có Binder client riêng

` scripts/shizuku-setup.sh:2-4,33-39` mô tả helper tùy chọn và kiểm tra `rish -c id`; repo không tự triển khai Binder/client hay luồng xin/cấp quyền. Installer chỉ chép helper (`install.sh:124-136`), còn lệnh phải được người dùng gọi riêng. `scripts/no-root-watchdog.sh:1-2` nêu rõ watchdog no-root không gọi Shizuku. Không có fallback tự động sang root. Shizuku/rish cung cấp quyền shell khi được cấp quyền bên ngoài repo; đó không phải root.

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
- **Dependency integrity:** `install.sh:209-210` cài pip mới nhất; lock pin phiên bản nhưng không hash artifact. Nên pin pip và cân nhắc lock hash/`--require-hashes`; đây là cải thiện chuỗi cung ứng, không phải lỗ hổng runtime mới được xác nhận.
- **Root trust:** root/Magisk chỉ được cài khi UID root và Magisk phát hiện được (`install.sh:15-21,103-118`); điều đó không làm cho script/library từ vùng Termux trở nên đáng tin.
- Thay đổi `.gitignore` riêng trên nhánh `fix/security` bỏ qua `SOUL.md` (`.gitignore:23`); đây không phải thay đổi runtime của diff no-root.

## Kiểm tra đã chạy

- `sh -n` trên 12 script shell tại `5622132` (installer, mọi `scripts/*.sh`, `service.d/*.sh`) — đạt.
- Biên dịch cú pháp `web/server.py` và `tests/no_root_harness.py` — đạt.
- `git diff --check e46da08 5622132` — đạt, không có whitespace lỗi.
- `python3 tests/no_root_harness.py` tại worktree tạm `5622132` — 8/8 đạt: shell/Python syntax, payload lock không chạy, root preflight từ chối lock path không tin cậy, mặc định host theo UID, custom venv qua Web UI, và installer dừng khi thiếu Python/git. Test HTTP chỉ bind loopback; installer tests dùng thư mục tạm và không cài package.
- Kiểm tra lịch sử trên bản trước vá `e46da08` đã xác nhận payload Python tạo marker; fixture tạm đã xóa. Harness mới xác nhận regression đã được chặn trên target.
- Không chạy installer lên hệ thống thật, không chạy ứng dụng hoặc lệnh Android/Shizuku, không truy cập/kiểm thử mạng trên OnePlus 11R.
