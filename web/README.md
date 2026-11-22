# Web UI — chat với bot qua Tailscale (port 3000)

Một web chat self-hosted, chạy trên điện thoại. Web UI **không có xác thực**: ai truy cập được cổng có thể gửi lệnh chat qua gateway. Không mở trực tiếp ra Internet.

## Yêu cầu

- Đã cài hermes-agent + gateway (xem `install.sh`).
- Web UI chỉ nên dùng trên giao diện mạng tin cậy; Tailscale là lựa chọn phù hợp nếu cấu hình bind đúng địa chỉ.

## Chạy

```sh
scripts/webui.sh start
scripts/webui.sh status
scripts/webui.sh stop
scripts/webui.sh restart
```

Mặc định cổng **3000**. Đổi bằng `WEBUI_PORT=8080`.

## Giao diện lắng nghe và bảo mật

- **Termux không root:** mặc định chỉ bind `127.0.0.1`, vì UI không có auth. Vì vậy máy khác không thể truy cập cho đến khi người dùng chủ động chọn host.
- **Root:** mặc định giữ hành vi cũ là bind `0.0.0.0` trên mọi giao diện để không làm đổi root flow. Vì UI không có auth, điều này có thể lộ UI trên LAN/Tailscale; không forward cổng ra Internet.
- Nếu cần truy cập từ xa ở chế độ no-root, ưu tiên bind đúng địa chỉ Tailscale của điện thoại, ví dụ:

```sh
WEBUI_HOST=100.x.y.z scripts/webui.sh start
```

Thay `100.x.y.z` bằng địa chỉ Tailscale thực tế. Đổi host cần restart Web UI. Không dùng `WEBUI_HOST=0.0.0.0` trừ khi chấp nhận UI không xác thực trên tất cả giao diện mạng.

Cổng và host có thể đặt cùng lúc:

```sh
WEBUI_HOST=127.0.0.1 WEBUI_PORT=8080 scripts/webui.sh start
```

## Watchdog

`service.d/05-watchdog.sh` tiếp tục revive web UI trong luồng root hiện có. Watchdog no-root chỉ quản lý Hermes gateway, không tự khởi chạy Web UI. Nếu cần chạy no-root, gọi `scripts/webui.sh start` rõ ràng sau khi đã chọn host phù hợp.

## Kiến trúc

```
Trình duyệt ──HTTP──> web/server.py (port 3000, không auth) ──> hermes run --message ──> gateway
```

`server.py` chỉ dùng stdlib (http.server, subprocess). Không cần npm, không cần Node. Chạy chung venv với gateway.
