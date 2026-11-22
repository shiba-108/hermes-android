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

# Root may install packages from this lock, so require a root-owned, non-writable
# path from the lock file through every parent directory. This is deliberately
# fail-closed when Android ownership/modes do not establish that trust boundary.
if [ "$(id -u 2>/dev/null || true)" = "0" ]; then
  if ! "$PY" -c '
import os
import stat
import sys

path = os.path.abspath(sys.argv[1])
current = path
while True:
    try:
        metadata = os.lstat(current)
    except OSError as exc:
        raise SystemExit(f"cannot inspect {current}: {exc}")
    if current == path:
        if not stat.S_ISREG(metadata.st_mode):
            raise SystemExit(f"lock is not a regular file: {current}")
    elif not stat.S_ISDIR(metadata.st_mode):
        raise SystemExit(f"path component is not a directory: {current}")
    if metadata.st_uid != 0:
        raise SystemExit(f"path is not owned by root: {current}")
    if metadata.st_mode & (stat.S_IWGRP | stat.S_IWOTH):
        raise SystemExit(f"path is writable by group/other: {current}")
    parent = os.path.dirname(current)
    if parent == current:
        break
    current = parent
' "$LOCK" >> "$LOG" 2>&1; then
    echo "LOCK TRUST FAILURE: refusing to inspect/install packages as root: $LOCK" >> "$LOG"
    echo "LOCK TRUST FAILURE: root ownership/mode of lock path is not trusted; refusing." >&2
    exit 1
  fi
fi

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
  if ! "$PY" -c 'import importlib.metadata as m,sys; sys.exit(0 if m.version(sys.argv[1])==sys.argv[2] else 1)' "$name" "$ver" >/dev/null 2>&1; then
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
