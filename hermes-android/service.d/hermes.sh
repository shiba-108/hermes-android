#!/system/bin/sh
export HOME=/data/local/hermes-home
export HERMES_HOME=/data/local/hermes-home
export PREFIX=/data/data/com.termux/files/usr
export PATH=/data/local/node-termux/data/data/com.termux/files/usr/bin:/data/local/hermes-venv/bin:/data/data/com.termux/files/usr/bin:/system/bin:/vendor/bin
export LD_LIBRARY_PATH=/data/data/com.termux/files/usr/lib:/data/local/node-termux/data/data/com.termux/files/usr/lib
export LD_PRELOAD=/data/data/com.termux/files/usr/lib/libpython3.14.so
export TMPDIR=/data/local/tmp
sleep 20
sh /data/local/hermes-home/scripts/preflight_venv.sh
nohup /data/local/hermes-venv/bin/hermes gateway run > /data/local/tmp/hermes.log 2>&1 &
