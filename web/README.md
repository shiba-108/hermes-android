# Web UI — chat với bot qua Tailscale (port 3000)

Một web chat tối giản, self-hosted, chạy ngay trên điện thoại. Truy cập từ laptop
qua Tailscale (hoặc LAN). **Không dùng tmux** — khởi động bằng `nohup` và được
watchdog canh sống.

## Yêu cầu

- Đã cài hermes-agent + gateway chạy được (xem `install.sh`).
- (Khuyến nghị) Tailscale để truy cập từ xa.

## Chạy

```sh
scripts/webui.sh start      # nohup, PID ở ~/webui.pid, log ở logs/webui.log
scripts/webui.sh status
scripts/webui.sh stop
scripts/webui.sh restart
```

Mặc định cổng **3000**. Đổi bằng biến môi trường:

```sh
WEBUI_PORT=8080 scripts/webui.sh start
```

## Truy cập

- **LAN:** `http://<ip-điện-thoại>:3000`
- **Tailscale:** `http://<tailscale-ip>:3000` hoặc `http://<machine-name>:3000`

Chỉ cần mở trình duyệt, gõ tin nhắn → server gọi `hermes run --message "..."` và
trả lời lại. Đồ họa tối giản (dark theme), chạy tốt trên mobile + desktop.

## Watchdog

`service.d/05-watchdog.sh` đã thêm đoạn tự revive webui mỗi 300s nếu `web/server.py`
tồn tại mà tiến trình chết. Nếu bạn dùng bản Termux thuần, thêm dòng này vào crontab:

```sh
*/5 * * * * /data/local/hermes-home/scripts/webui.sh start
```

## Bảo mật

- Web UI **không có auth**. Chỉ bind trong mạng Tailscale/LAN của bạn.
- Nếu muốn mở ra Internet, hãy đặt sau Tailscale serve/funnel hoặc reverse proxy
  có auth. **Không** expose trực tiếp cổng 3000 ra Internet.

## Kiến trúc

```
Trình duyệt ──HTTP──> web/server.py (port 3000) ──> hermes run --message ──> gateway ──> Telegram/model
```

`server.py` chỉ dùng stdlib (http.server, subprocess). Không cần npm, không cần
Node. Chạy chung venv với gateway.