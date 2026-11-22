# 🔐 Sao lưu (Backup) — không bao giờ lộ secret

Mục tiêu: giữ an toàn `.env`, `auth.json`, `config.yaml`, `sessions/` trước khi
mất máy / reset / cài lại — **mà không bao giờ đẩy secret lên repo public**.

## Nguyên tắc

1. **Mã hoá trước khi rời khỏi máy.** Archive luôn được mã hoá bằng `age` (hoặc
   `gpg` fallback) trước khi upload bất cứ đâu.
2. **Repo public = tuyệt đối không.** `hermes-android` public KHÔNG bao giờ chứa
   `.env` / `auth.json` / `config.yaml` / `sessions/`. Tất cả đã nằm trong
   `.gitignore`.
3. **Đẩy lên nơi private:** GitHub private repo (remote riêng) hoặc Google Drive
   (`rclone`). Chỉ ngưọi giữ private key giải mã được.

## Dùng nhanh

```sh
# 1) Tạo archive mã hoá cục bộ (mặc định)
scripts/backup.sh

# 2) Đẩy lên GitHub private (cần remote tên 'secret-remote' trỏ tới private repo)
scripts/backup.sh --push

# 3) Đẩy lên Google Drive (cần rclone remote 'gdrive')
scripts/backup.sh --drive
```

Kết quả nằm ở `~/backups/hermes-secret-<timestamp>.tar.gz.enc`.

## Cài age (khuyến nghị)

```sh
# Termux
pkg install age
age-keygen -o ~/.ssh/age.key        # private key — GIỮ KÍN
# public key (AGE_RECIPIENT) để mã hoá:
export AGE_RECIPIENT="age1..."
```

`backup.sh` tự dùng `AGE_RECIPIENT` (hoặc `~/.ssh/age.pub`) để mã hoá.
**Khôi phục:** `age -d -i ~/.ssh/age.key backup.tar.gz.enc | tar -xz -C ~/restore`

## GitHub private repo (remote 'secret-remote')

```sh
# 1) Tạo private repo trên GitHub (vd: shiba-108/hermes-secrets) — để PRIVATE.
# 2) Thêm remote trong thư mục backups (KHÔNG phải repo public này):
cd ~/backups
git init 2>/dev/null || true
git remote remove secret-remote 2>/dev/null || true
git remote add secret-remote git@github.com:shiba-108/hermes-secrets.git
```

Sau đó `scripts/backup.sh --push` sẽ commit file `.enc` và đẩy lên private.

> ⚠️ Chỉ file `.enc` (đã mã hoá) được đẩy. Private key age **không bao giờ** lên git.

## Google Drive qua rclone

```sh
pkg install rclone
rclone config          # tạo remote tên 'gdrive'
scripts/backup.sh --drive
```

## Lịch tự động (tùy chọn)

Thêm vào watchdog hoặc cron Android (Termux:API):

```sh
# Mỗi ngày 03:00
0 3 * * * /data/local/hermes-home/scripts/backup.sh --push >> ~/logs/backup.log 2>&1
```

## Kiểm tra

- `git -C ~/backups status` → chỉ thấy `*.enc`.
- Repo public `hermes-android`: `git ls-files | grep -E '\.env|auth.json|config.yaml'` → **rỗng**.

## Lỗi thường gặp

- **`permission denied (publickey)` khi push:** thêm SSH key vào GitHub, xem `BI-KIP.md`.
- **age không có key:** export `AGE_RECIPIENT` hoặc tạo `~/.ssh/age.pub`.
- **rclone chưa config:** chạy `rclone config` một lần.