# BÍ KÍP vận hành Hermes trên Android

Thu thập từ skill `sys-status`, `sys-logs`, `sys-restart`, `sys-maintenance`.

## Mục lục

1. [Check hệ thống](#1-check-hệ-thống-read-only)
2. [Xem log](#2-xem-log)
3. [Restart gateway](#3-restart-gateway)
4. [Watchdog](#4-watchdog)
5. [venv + lock](#5-venv--lock)
6. [Dọn app](#6-dọn-app)
7. [Đánh giá sinh tồn](#7-đánh-giá-sinh-tồn)
8. [Model free + lỗi menu /model cache 63 con](#8-model-free--lỗi-menu-model-cache-63-con)
9. [Set model bằng config set](#9-set-model-bằng-config-set)
10. [SSH key + lỗi Permission denied publickey](#10-ssh-key--lỗi-permission-denied-publickey)
11. [Web UI (port 3000)](#11-web-ui-port-3000)
12. [Backup](#12-backup)
13. [Pitfalls](#pitfalls)

---

## 1. Check hệ thống (read-only)

```sh
pgrep -f doh-proxy
pgrep -f "gateway run|gateway restart"
pgrep -f com.tailscale.ipn
pgrep -f 05-watchdog
pgrep -f web/server.py          # web UI (nếu bật)
timeout 5 ping -c 1 google.com
```

Báo PID hoặc NOT RUNNING + kết quả ping. **Không** kill/restart khi chỉ check.

## 2. Xem log

```sh
tail -n 50 /data/local/hermes-home/logs/gateway.log
tail -n 30 /data/local/hermes-home/logs/errors.log   # khi hỏi lỗi
tail -n 30 /data/local/hermes-home/logs/preflight.log # lỗi venv
tail -n 20 /data/local/hermes-home/logs/webui.log    # lỗi web UI
```

Trả về 20-30 dòng đáng chú ý nhất, không dán nguyên log.

## 3. Restart gateway

**Luôn hỏi Yes/No trước.** Chỉ khi user chọn Yes mới chạy:

```sh
hermes gateway restart
```

Xong báo PID mới (`pgrep -f "gateway run|gateway restart"`) + dòng `Connected` cuối trong log.

## 4. Watchdog

`05-watchdog.sh` mỗi 300s nuôi lại doh/gateway/tailscale/webui. Điều kiện gateway
phải là **cả** hai: `pgrep -f "gateway run|gateway restart"` **và**
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

## 8. Model free + lỗi menu /model cache 63 con

**Chỉ dùng model free (KHÔNG bao giờ dùng model trả phí):**

| Vai trò | Model |
|---|---|
| Mặc định | `baidu/ernie-5.5-flash-preview:free` |
| Dự phòng 1 | `inclusionai/ling-3.2-flash:free` |
| Dự phòng 2 | `particle-ai/particle-1:free` |

**Lỗi menu `/model` hiện 63 con (rác):** do cache model cũ từ nhà cung cấp khác
được nạp vào menu. Cách sửa:

```sh
# 1) Xóa cache model (kiểm tra bằng hermes config get trước)
hermes config get model.default          # xem đang set gì

# 2) Xóa cache menu model (file cache)
rm -f /data/local/hermes-home/provider_models_cache.json
rm -f /data/local/hermes-home/models_dev_cache.json
rm -f /data/local/hermes-home/models_dev_cache.etag
rm -f /data/local/hermes-home/context_length_cache.yaml

# 3) Đặt lại model free (mục 9)
```

Sau khi xóa cache, mở menu `/model` lại → chỉ còn model free của provider hiện tại.
Nếu menu vẫn còn 63 con, kiểm tra `hermes config get model.fallbacks` xem có
model cũ nào sót không.

## 9. Set model bằng config set

**Không sửa tay `config.yaml`** (dễ sai `_config_version`, hỏng schema). Dùng CLI:

```sh
# Xem hiện tại
hermes config get model.default
hermes config get model.provider

# Đặt model mặc định (free)
hermes config set model.default baidu/ernie-5.5-flash-preview:free

# Đặt provider
hermes config set model.provider openrouter

# Đặt fallback (list) — nếu CLI hỗ trợ, nếu không thì sửa config.yaml cẩn thận
# hermes config set model.fallbacks '["inclusionai/ling-3.2-flash:free","particle-ai/particle-1:free"]'
```

`config.yaml` hiện tại đang đúng chuẩn (mục `model:`), KHÔNG cần sửa nếu đã có.

> ⚠️ Sau khi `config set` xong phải restart gateway để nạp model mới. Hỏi Yes/No trước.

## 10. SSH key + lỗi Permission denied publickey

Lỗi `git@github.com: Permission denied (publickey)` khi push:

```sh
# 1) Kiểm tra có key chưa
ls -la ~/.ssh/

# 2) Nếu chưa có, tạo key mới
ssh-keygen -t ed25519 -C "hermes-android@$(hostname)" -f ~/.ssh/id_ed25519
#   (Enter để trống passphrase, hoặc đặt passphrase rồi dùng ssh-agent)

# 3) Copy public key
cat ~/.ssh/id_ed25519.pub
```

Thêm public key vào GitHub: **Settings → SSH and GPG keys → New SSH key** → dán
nội dung `id_ed25519.pub` → Add.

Kiểm tra kết nối:

```sh
ssh -T git@github.com
# mong đợi: Hi <user>/hermes-android! You've successfully authenticated...
```

Nếu vẫn lỗi:
- `ssh-add ~/.ssh/id_ed25519` (nạp key vào agent).
- Kiểm tra `~/.ssh/config` có entry `github.com` trỏ đúng key chưa.
- Đảm bảo repo remote đúng: `git remote -v` → `git@github.com:shiba-108/hermes-android.git`.
- Nếu dùng `https://` remote, đổi sang SSH: `git remote set-url origin git@github.com:shiba-108/hermes-android.git`.

## 11. Web UI (port 3000)

```sh
scripts/webui.sh start     # nohup, PID ở ~/webui.pid
scripts/webui.sh status
scripts/webui.sh stop / restart
```

- Truy cập qua Tailscale: `http://<tailscale-ip>:3000` hoặc LAN `http://<ip>:3000`.
- Watchdog `05-watchdog.sh` tự revive webui nếu chết.
- Chi tiết: `web/README.md`.

## 12. Backup

```sh
scripts/backup.sh          # tạo archive mã hoá age vào backups/
scripts/backup.sh --push   # đẩy lên GitHub private (remote 'secret-remote')
scripts/backup.sh --drive  # đẩy lên Google Drive (rclone 'gdrive')
```

- Chỉ đẩy file `.enc` (đã mã hoá). Private key KHÔNG BAO GIỜ lên git.
- Chi tiết: `docs/BACKUP.md`.

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
- Đừng sửa tay `config.yaml` (dễ sai `_config_version`). Luôn `hermes config set/get`.
- Sau khi sửa `config.yaml` hoặc `config set` → phải restart gateway mới nạp.