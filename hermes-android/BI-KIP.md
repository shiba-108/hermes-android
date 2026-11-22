# BÍ KÍP vận hành Hermes trên Android

Thu thập từ skill `sys-status`, `sys-logs`, `sys-restart`, `sys-maintenance`.

## 1. Check hệ thống (read-only)

```sh
pgrep -f doh-proxy
pgrep -f "gateway run|gateway restart"
pgrep -f com.tailscale.ipn
pgrep -f 05-watchdog
timeout 5 ping -c 1 google.com
```

Báo PID hoặc NOT RUNNING + kết quả ping. **Không** kill/restart khi chỉ check.

## 2. Xem log

```sh
tail -n 50 /data/local/hermes-home/logs/gateway.log
tail -n 30 /data/local/hermes-home/logs/errors.log   # khi hỏi lỗi
```

Trả về 20-30 dòng đáng chú ý nhất, không dán nguyên log.

## 3. Restart gateway

**Luôn hỏi Yes/No trước.** Chỉ khi user chọn Yes mới chạy:

```sh
hermes gateway restart
```

Xong báo PID mới (`pgrep -f "gateway run|gateway restart"`) + dòng `Connected` cuối trong log.

## 4. Watchdog

`05-watchdog.sh` mỗi 300s nuôi lại doh/gateway/tailscale. Điều kiện gateway phải là
**cả** hai: `pgrep -f "gateway run|gateway restart"` **và**
`tail -n 100 logs/gateway.log | grep -q "Connected to Telegram"`.
Chỉ `pgrep` là không đủ: process sống nhưng crash-loop vẫn tính là "sống".

Sửa `service.d/*.sh` → `cp -a <file> <file>.bak` → `sh -n` → **restart watchdog** để nạp code
(shell đọc script theo lô, đổi nội dung mà không restart thì chạy code cũ hoặc corrupt).

## 5. venv + lock

- Lock đang chạy: `backups/venv-requirements.lock` (freeze 28 gói).
- Lock Android đầy đủ: `backups/venv-requirements.android.lock` (59 gói, từ `uv.lock`).
- `scripts/make_lock.py`: đọc `uv.lock` bằng `tomllib`, BFS từ `[project].dependencies`
  → ra lock full + lock Android. **Chỉ resolve, không build.**
- `scripts/preflight_venv.sh`: đối chiếu từng gói với lock, thiếu/lệch thì `pip install -r lock`,
  ghi `logs/preflight.log`. Gắn vào `hermes.sh` + watchdog trước `gateway run`.
- **Không** tự nâng version khi lock lệch pyproject: đó là thay đổi môi trường đang chạy,
  phải hỏi user + test trong venv riêng.

## 6. Dọn app

- `pm list packages -3` (đang cài), `-3 -e` (đang bật), `-d` (đã disable).
- Google rác disable an toàn: Files, work.clouddpc, onetimeinitializer, partnersetup,
  apps.restore, configupdater, hotwordenrollment, adm, contactkeys, verifier,
  ambient.streaming, adservices, federatedcompute, ondevicepersonalization, rkpdapp,
  healthdata, healthconnect, switchaccess, talkback.
- Bloat OPLUS/OnePlus (heytap.market, themestore, aiunit...) → hỏi thêm.
- `pm disable-user --user 0 <pkg>`; bật lại bằng `pm enable`. Không bao giờ uninstall.

## 7. Đánh giá sinh tồn

Thu thập: `uptime`, `cat /data/adb/service.d/*.sh`, `cat ~/.termux/boot/start.sh`,
`dumpsys deviceidle whitelist`, `dumpsys battery`, `free -h`, `df -h /data`,
`tail logs/boot.log`.

Kịch bản bắt buộc: mất điện, mất mạng, Android kill, reboot, hết RAM, hết disk.
Chỉ đề xuất, không tự sửa.

## Pitfalls

- `pgrep -af <pattern>` khớp cả shell snapshot của lệnh terminal (cmdline chứa pattern) → PID rác.
  Dùng `pgrep -f` hoặc `ps -eo pid,etime,args | grep -E ... | grep -v 'bash -c'`.
- `pgrep -f "hermes gateway run"` không khớp gateway khởi động qua `gateway restart`.
- `pm disable-user` với package mainline/ẩn (`com.google.android.mainline.adservices`)
  có thể trả `Unknown package` dù `pm list packages` hiện → bỏ qua.
- `nemo-relay` có marker `'android' not in platform_release` → thiếu `nemo_relay` trên Android
  là thiết kế có chủ ý, relay_runtime fail là bình thường.
- `psutil` trên Android là bản git, không phải registry.
- Các mount `/`, `/system_ext`, `/vendor`, `/odm` hiện 100% là bình thường (read-only).
- `uv`/full `pip install -e .` trên Android kẹt ở build `cryptography`, `watchfiles`,
  `firecrawl-anydoc` từ source → dùng `uv.lock` resolve thay vì cài full.
