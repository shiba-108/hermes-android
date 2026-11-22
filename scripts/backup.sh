#!/system/bin/sh
# =============================================================================
# scripts/backup.sh — sao lưu mã hoá secret + sessions, KHÔNG bao giờ lên repo public.
#
#   scripts/backup.sh            # tạo archive mã hoá age vào backups/
#   scripts/backup.sh --push     # tạo + đẩy lên GitHub private repo (cần git remote)
#   scripts/backup.sh --drive    # tạo + đẩy lên Google Drive qua rclone
#
# Mã hoá: age (nếu có) hoặc gpg (fallback). KHÔNG dùng password plaintext.
# Public key age nhận qua biến môi trường AGE_RECIPIENT (hoặc ~/.ssh/age.pub).
# =============================================================================
set -u

HM="${HERMES_HOME:-/data/local/hermes-home}"
OUT_DIR="$HM/backups"
TS=$(date +%Y%m%d-%H%M%S)
ARCHIVE="$OUT_DIR/hermes-secret-$TS.tar.gz"
MODE="${1:-local}"

mkdir -p "$OUT_DIR"
umask 077

echo "==> Đóng gói secret..."
# Danh sách file/dir cần backup (chỉ đọc, không sửa)
ITEMS=""
for p in ".env" "auth.json" "config.yaml" "sessions" "SOUL.md"; do
  [ -e "$HM/$p" ] && ITEMS="$ITEMS $p"
done

if [ -z "$ITEMS" ]; then
  echo "Không tìm thấy secret nào ở $HM. Thoát."; exit 0
fi

# -C để archive chứa đường dẫn tương đối, không lộ /data/local
tar -czf "$ARCHIVE" -C "$HM" $ITEMS 2>/dev/null
echo "  -> $ARCHIVE"

# ---------------------------------------------------------------------------
# Mã hoá
# ---------------------------------------------------------------------------
ENC="$ARCHIVE.enc"
if command -v age >/dev/null 2>&1 && [ -n "${AGE_RECIPIENT:-}" ]; then
  echo "==> Mã hoá bằng age (recipient $AGE_RECIPIENT)..."
  age -r "$AGE_RECIPIENT" -o "$ENC" "$ARCHIVE" && rm -f "$ARCHIVE" \
    && echo "  -> $ENC" || { echo "LỖI age"; exit 1; }
elif command -v age >/dev/null 2>&1 && [ -f "$HOME/.ssh/age.pub" ]; then
  REC=$(cat "$HOME/.ssh/age.pub" | awk '{print $1" "$2}')
  echo "==> Mã hoá bằng age ($REC)..."
  age -r "$REC" -o "$ENC" "$ARCHIVE" && rm -f "$ARCHIVE" \
    && echo "  -> $ENC" || { echo "LỖI age"; exit 1; }
elif command -v gpg >/dev/null 2>&1 && [ -n "${GPG_RECIPIENT:-}" ]; then
  echo "==> Mã hoá bằng gpg (recipient $GPG_RECIPIENT)..."
  gpg --encrypt --recipient "$GPG_RECIPIENT" --output "$ENC" "$ARCHIVE" \
    && rm -f "$ARCHIVE" && echo "  -> $ENC" || { echo "LỖI gpg"; exit 1; }
else
  echo "CẢNH BÁO: không có age/gpg. Archive $ARCHIVE CHƯA MÃ HOÁ."
  echo "  KHÔNG đẩy file này lên bất kỳ đâu. Cài age trước khi dùng --push/--drive."
fi

# ---------------------------------------------------------------------------
# Đẩy lên remote (chỉ khi được yêu cầu rõ ràng)
# ---------------------------------------------------------------------------
case "$MODE" in
  --push)
    echo "==> Đẩy lên GitHub private..."
    cd "$OUT_DIR" || exit 1
    # Giả định user đã có private repo + remote tên 'secret-remote'
    if git remote get-url secret-remote >/dev/null 2>&1; then
      cp -a "$ENC" ./ 2>/dev/null || true
      git add "$ENC" && git commit -m "backup $TS" >/dev/null 2>&1 && \
        git push secret-remote HEAD 2>&1 | tail -3 || echo "  (không có gì để đẩy)"
      rm -f "$ENC"
      echo "  xong. Nhớ rm file .enc local sau khi đẩy nếu không cần."
    else
      echo "  CẢNH BÁO: chưa cấu hình remote 'secret-remote'. Bỏ qua."
      echo "  Xem docs/BACKUP.md phần 'GitHub private'."
    fi
    ;;
  --drive)
    if command -v rclone >/dev/null 2>&1; then
      echo "==> Đẩy lên Google Drive (rclone remote 'gdrive')..."
      rclone copy "$ENC" "gdrive:hermes-backups/" 2>&1 | tail -3 \
        && echo "  xong" || echo "  LỖI rclone"
    else
      echo "  CẢNH BÁO: không có rclone. Cài rclone + cấu hình remote 'gdrive'."
    fi
    ;;
  *)
    echo "==> Chế độ local: chỉ tạo archive tại $OUT_DIR (không đẩy đi đâu)."
    ;;
esac

echo
echo "Xong. Giải mã: age -d -i <private-key> $ENC | tar -xz -C <dir>  (hoặc gpg -d)"
echo "LƯU Ý: secret đã mã hoá KHÔNG BAO GIỜ nằm trong repo public hermes-android."