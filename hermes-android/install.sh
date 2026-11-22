#!/system/bin/sh
# Cai dat hermes-android: service.d -> /data/adb/service.d, scripts -> hermes-home/scripts,
# locks -> hermes-home/backups. Idempotent, tu backup ban cu.
set -e

REPO=$(cd "$(dirname "$0")" && pwd)
SD=/data/adb/service.d
HM=/data/local/hermes-home
TS=$(date +%Y%m%d-%H%M%S)

mkdir -p "$SD" "$HM/scripts" "$HM/backups"

echo "== service.d =="
for f in "$REPO"/service.d/*.sh; do
  [ -e "$f" ] || continue
  b=$(basename "$f")
  if [ -f "$SD/$b" ]; then
    cp -a "$SD/$b" "$SD/$b.bak.$TS"
    echo "  backup $SD/$b -> $b.bak.$TS"
  fi
  cp -a "$f" "$SD/$b"
  chmod 755 "$SD/$b"
  echo "  install $SD/$b"
done

echo "== scripts =="
for f in "$REPO"/scripts/*; do
  [ -e "$f" ] || continue
  b=$(basename "$f")
  if [ -f "$HM/scripts/$b" ]; then
    cp -a "$HM/scripts/$b" "$HM/scripts/$b.bak.$TS"
  fi
  cp -a "$f" "$HM/scripts/$b"
  chmod 755 "$HM/scripts/$b"
  echo "  install $HM/scripts/$b"
done

echo "== locks =="
for f in "$REPO"/locks/*; do
  [ -e "$f" ] || continue
  b=$(basename "$f")
  if [ ! -f "$HM/backups/$b" ]; then
    cp -a "$f" "$HM/backups/$b"
    echo "  install $HM/backups/$b"
  else
    echo "  giu nguyen $HM/backups/$b"
  fi
done

echo "== skills (chi cai khi chua co) =="
for d in "$REPO"/skills/*/; do
  [ -d "$d" ] || continue
  n=$(basename "$d")
  if [ ! -f "$HM/skills/$n/SKILL.md" ]; then
    mkdir -p "$HM/skills/$n"
    cp -a "$d/SKILL.md" "$HM/skills/$n/SKILL.md"
    echo "  install skills/$n"
  else
    echo "  giu nguyen skills/$n"
  fi
done

echo
echo "Xong. service.d co hieu luc sau reboot; neu da co tien trinh dang chay thi restart de nap code."
