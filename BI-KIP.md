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
11. [Chạy không root vs có root](#11-chạy-không-root-vs-có-root)
12. [Web UI (port 3000)](#12-web-ui-port-3000)
13. [Backup](#13-backup)
14. [Pitfalls](#pitfalls)

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

Có hai watchdog khác nhau, không được coi chúng là cùng một tính năng:

- **Root + Magisk:** `service.d/05-watchdog.sh` kiểm tra mỗi 300 giây. Script hiện có thể khởi động lại gateway khi process không thấy hoặc log gần nhất không có `Connected to Telegram`; đồng thời thử giữ các tiến trình DoH, Web UI và Tailscale. Đây là hành vi của script root hiện có, chưa được kiểm thử Android trong beta này.
- **Termux không root:** `scripts/no-root-watchdog.sh` kiểm tra mỗi 300 giây và chỉ quản lý gateway do chính nó khởi chạy. Nó không quản lý Telegram health, DoH, Web UI, Tailscale, package Android, Doze hay Private DNS. Process còn chạy không chứng minh bot đã kết nối.

Termux:Boot là tùy chọn và installer không tự đăng ký hook. `start-manual.sh` chỉ dùng trong Termux không root; nó từ chối chạy dưới UID 0. Root không Magisk không có boot hook được dự án hỗ trợ.

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

Không có danh sách package hệ thống nào được xác nhận là “an toàn để disable” trên mọi máy. Tên package và tác động khác nhau theo Android/ROM; đừng chạy lệnh bulk hoặc dùng danh sách cũ trên mạng.

Shizuku helper chỉ cho phép xem hoặc disable **một package bên thứ ba được chỉ rõ**; nó từ chối package hệ thống và chỉ hoàn tác mục do chính helper ghi nhận. Xem `scripts/shizuku-setup.sh --help` và `docs/NO-ROOT.md` trước khi thay đổi. Nếu không chắc package đó làm gì, đừng disable.

## 7. Đánh giá sinh tồn

Thu thập: `uptime`, `cat /data/adb/service.d/*.sh`, `cat ~/.termux/boot/start.sh`,
`dumpsys deviceidle whitelist`, `dumpsys battery`, `free -h`, `df -h /data`,
`tail logs/boot.log`.

Kịch bản bắt buộc: mất điện, mất mạng, Android kill, reboot, hết RAM, hết disk.
Chỉ đề xuất, không tự sửa.

## 8. Model free + lỗi menu /model cache 63 con

Danh sách model, nhãn “free”, hạn mức và giá có thể đổi theo provider; không coi model cụ thể nào trong ghi chú cũ là miễn phí hiện tại. Kiểm tra giá và hạn mức trực tiếp với provider trước khi chọn.

Nếu menu `/model` có lựa chọn cũ, kiểm tra cấu hình hiện tại trước:

```sh
hermes config get model.default
hermes config get model.provider
hermes config get model.fallbacks
```

Không xóa file cache theo đường dẫn cố định nếu chưa xác nhận đường dẫn và hướng dẫn của đúng phiên bản Hermes đang cài. Nếu cần đổi lựa chọn, dùng lệnh cấu hình ở mục tiếp theo và kiểm tra lại menu.

## 9. Set model bằng config set

**Không sửa tay `config.yaml`** (dễ sai `_config_version`, hỏng schema). Dùng CLI:

```sh
# Xem hiện tại
hermes config get model.default
hermes config get model.provider

# Đặt model mặc định theo đúng provider/model đã kiểm tra giá
hermes config set model.default <provider/model>

# Đặt provider
hermes config set model.provider openrouter

# Cấu hình fallback theo cú pháp được phiên bản Hermes hiện tại hỗ trợ
```

Đừng giả định fallback nào cũng miễn phí; kiểm tra từng lựa chọn với provider. Không tự sửa `config.yaml` nếu chưa biết schema của phiên bản đang chạy.

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

## 11. Chạy không root vs có root

Installer tự phát hiện UID và Magisk rồi in chế độ khi chạy. Các luồng dưới đây khác nhau:

| Chế độ | Điều kiện | Làm được | Sau reboot |
|---|---|---|---|
| root + Magisk | UID 0 và Magisk | chép các script hiện có vào `service.d/`; gồm các thao tác root như ADB-over-TCP và iptables/DNS | script service.d chạy khi boot theo Magisk |
| root, không Magisk | UID 0, không Magisk | installer vẫn cài tệp dự án nhưng bỏ qua `service.d/`; repo không cấu hình boot cho chế độ này | chưa có tự khởi động do repo cấu hình |
| Termux không root | UID khác 0 | cài trong home Termux; watchdog no-root chỉ quản lý gateway | chạy tay hoặc tự chọn Termux:Boot |

**Termux không root:** sau reboot, chỉ khi không dùng Termux:Boot thì khởi chạy thủ công:

```sh
sh "$HOME/.hermes-home/scripts/start-manual.sh"
```

`start-manual.sh` chuyển tiếp sang no-root watchdog và từ chối UID 0. Watchdog không khởi chạy Web UI hay Tailscale, và không chứng minh kết nối Telegram.

Termux:Boot cần được cài/mở riêng, sau đó đăng ký hook chủ động bằng `sh $HERMES_HOME/scripts/termux-boot.sh install`. Gỡ bằng `uninstall`; gỡ hook không tự dừng gateway/watchdog. Hướng dẫn chi tiết nằm trong `docs/NO-ROOT.md`.

## 12. Web UI (port 3000)

```sh
scripts/webui.sh start     # nohup, PID ở ~/webui.pid
scripts/webui.sh status
scripts/webui.sh stop / restart
```

- Web UI **không có xác thực**. Root mặc định bind `0.0.0.0` (mọi giao diện); Termux không root mặc định bind `127.0.0.1` (chỉ local). Muốn bind địa chỉ khác phải đặt `WEBUI_HOST` rõ ràng.
- Chỉ mở từ xa nếu bạn hiểu rủi ro và giới hạn truy cập vào mạng tin cậy; đừng phơi UI ra Internet công cộng. Watchdog root Magisk hiện có thể thử khởi chạy lại UI; watchdog no-root thì không quản lý UI.
- Chi tiết: `web/README.md`.

## 13. Backup

```sh
scripts/backup.sh          # tạo archive mã hoá age vào backups/
scripts/backup.sh --push   # đẩy lên GitHub private (remote 'secret-remote')
scripts/backup.sh --drive  # đẩy lên Google Drive (rclone 'gdrive')
```

- Chỉ đẩy file `.enc` (đã mã hoá). Private key KHÔNG BAO GIỜ lên git.
- Chi tiết: `docs/BACKUP.md`.

## 14. Pitfalls

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
