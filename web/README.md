# Web UI — chat với bot (cổng 3000)

Web UI self-hosted chạy trên điện thoại. Ứng dụng **không có xác thực**: bất kỳ ai truy cập được cổng đều có thể gửi lệnh chat qua Hermes gateway. Không mở trực tiếp ra Internet.

## Yêu cầu và chạy

- Đã cài hermes-agent + gateway (xem `install.sh`).
- Cổng mặc định là **3000**; đổi bằng `WEBUI_PORT=8080`.

```sh
scripts/webui.sh start
scripts/webui.sh status
scripts/webui.sh stop
scripts/webui.sh restart
```

## Bind và truy cập từ xa an toàn

- **Termux không root:** mặc định chỉ bind `127.0.0.1`; các thiết bị khác không thể truy cập trực tiếp.
- **Root-mode:** vẫn giữ mặc định cũ `0.0.0.0` trên mọi giao diện để không đổi luồng hiện tại. Web UI không xác thực và tiến trình có thể chạy với quyền root; thiết bị trên LAN/Tailscale có thể gửi lệnh tới gateway nếu mạng cho phép. Đây là rủi ro bảo mật đã biết, không phải chế độ được khuyến nghị.
- **Truy cập riêng qua Tailscale:** ưu tiên để Web UI bind loopback, rồi dùng [Tailscale Serve](https://tailscale.com/docs/reference/tailscale-cli/serve) làm reverse proxy nội bộ tailnet:

```sh
# Chỉ cần nếu đang ở root-mode; no-root đã mặc định loopback.
WEBUI_HOST=127.0.0.1 scripts/webui.sh restart

# Trên thiết bị có Web UI chạy ở cổng 3000:
tailscale serve 3000
tailscale serve status

# Khi muốn ngừng chia sẻ:
tailscale serve off
```

Mở URL HTTPS mà `tailscale serve status` hiển thị từ thiết bị trong tailnet. Serve chỉ chia sẻ trong tailnet, nhưng vẫn cần giới hạn quyền truy cập bằng ACL/grants và chỉ cho người/thiết bị đáng tin cậy vì chính Web UI không có đăng nhập. **Không dùng Tailscale Funnel** nếu không muốn công khai dịch vụ ra Internet.

## Truy cập qua LAN

Không bind trực tiếp Web UI hiện tại ra LAN: ứng dụng không có xác thực. Nếu cần truy cập LAN, chỉ cân nhắc cấu hình rõ một địa chỉ LAN cụ thể (không dùng wildcard `0.0.0.0`) sau khi đã đặt Web UI sau reverse proxy có xác thực và cấu hình firewall giới hạn nguồn truy cập. Không có proxy xác thực và firewall phù hợp thì hãy giữ loopback.

Có thể đặt host/cổng tường minh, ví dụ giữ loopback và đổi cổng:

```sh
WEBUI_HOST=127.0.0.1 WEBUI_PORT=8080 scripts/webui.sh start
```

`WEBUI_HOST` là opt-in rõ ràng; đổi host cần restart Web UI. Không dùng `WEBUI_HOST=0.0.0.0` trừ khi đã chủ động xử lý xác thực và giới hạn mạng cho mọi giao diện.

## Watchdog và kiến trúc

`service.d/05-watchdog.sh` tiếp tục revive Web UI trong luồng root hiện có. Watchdog no-root chỉ quản lý Hermes gateway, không tự khởi chạy Web UI; nếu cần chạy ở no-root, gọi `scripts/webui.sh start`.

```text
Trình duyệt ──HTTP──> web/server.py (cổng 3000, không auth) ──> hermes run --message ──> gateway
```

`server.py` chỉ dùng thư viện chuẩn Python; không cần npm hay Node. `HERMES_VENV` được dùng để chọn Hermes CLI cho `/api/send`.
