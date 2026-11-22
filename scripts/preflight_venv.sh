#!/system/bin/sh
# Preflight hermes-venv: compare installed packages to a pinned lock and repair drift.
# Root defaults remain unchanged; Termux no-root uses only its own home and Android lock.
set -u

if [ -n "${HERMES_HOME:-}" ]; then
  HM=$HERMES_HOME
elif [ "$(id -u 2>/dev/null || true)" = "0" ]; then
  HM=/data/local/hermes-home
else
  HM="${HOME:-/data/data/com.termux/files/home}/.hermes-home"
fi
if [ -n "${HERMES_VENV:-}" ]; then
  VENV=$HERMES_VENV
elif [ "$(id -u 2>/dev/null || true)" = "0" ]; then
  VENV=/data/local/hermes-venv
else
  VENV="${HOME:-/data/data/com.termux/files/home}/hermes-venv"
fi
PY="$VENV/bin/python"
if [ -n "${HERMES_LOCK:-}" ]; then
  LOCK=$HERMES_LOCK
elif [ "$(id -u 2>/dev/null || true)" = "0" ]; then
  LOCK="$HM/backups/venv-requirements.lock"
else
  LOCK="$HM/backups/venv-requirements.android.lock"
  [ -f "$LOCK" ] || LOCK="$HM/backups/venv-requirements.lock"
fi
LOG="$HM/logs/preflight.log"

mkdir -p "$HM/logs"
echo "=== preflight $(date '+%F %T') ===" >> "$LOG"

[ -f "$LOCK" ] || { echo "LOCK NOT FOUND: $LOCK" >> "$LOG"; exit 1; }
[ -x "$PY" ] || { echo "PYTHON NOT FOUND: $PY" >> "$LOG"; exit 1; }

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
