#!/system/bin/sh
# Preflight hermes-venv: kiem tra tung goi trong lock file con dung ban, thieu/lech thi tu cai lai.
# Chi doc trang thai + cai lai, khong restart gateway.
PY=/data/local/hermes-venv/bin/python
LOCK=/data/local/hermes-home/backups/venv-requirements.lock
LOG=/data/local/hermes-home/logs/preflight.log

mkdir -p /data/local/hermes-home/logs
echo "=== preflight $(date '+%F %T') ===" >> "$LOG"

[ -f "$LOCK" ] || { echo "LOCK NOT FOUND: $LOCK" >> "$LOG"; exit 1; }

broken=0
while IFS= read -r line; do
  case "$line" in
    ''|'#'*|'-'*) continue ;;
  esac
  case "$line" in
    *' @ '*) continue ;;
  esac
  name=${line%%==*}
  ver=${line##*==}
  [ -n "$name" ] || continue
  [ -n "$ver" ] || continue
  if ! "$PY" -c "import importlib.metadata as m,sys; sys.exit(0 if m.version('$name')=='$ver' else 1)" >/dev/null 2>&1; then
    echo "MISMATCH/MISSING: $line" >> "$LOG"
    broken=1
  fi
done < "$LOCK"

if [ "$broken" = 1 ]; then
  echo "repairing from lock..." >> "$LOG"
  "$PY" -m pip install -r "$LOCK" >> "$LOG" 2>&1
  echo "repair rc=$?" >> "$LOG"
fi

"$PY" -m pip check >> "$LOG" 2>&1
echo "preflight done" >> "$LOG"
