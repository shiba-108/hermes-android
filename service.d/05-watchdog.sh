#!/system/bin/sh
sleep 60
while true
do
  if ! pgrep -f doh-proxy.py > /dev/null 2>&1
  then
    setsid /data/data/com.termux/files/usr/bin/python /data/data/com.termux/files/home/doh-proxy.py &
    sleep 2
    iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-port 53
  fi
  GLOG=/data/local/hermes-home/logs/gateway.log
  if ! pgrep -f "gateway run|gateway restart" > /dev/null 2>&1 || ! tail -n 100 "$GLOG" 2>/dev/null | grep -q "Connected to Telegram"
  then
    pkill -f "gateway run|gateway restart" > /dev/null 2>&1
    sleep 2
    export HOME=/data/local/hermes-home
    export HERMES_HOME=/data/local/hermes-home
    export PREFIX=/data/data/com.termux/files/usr
    export PATH=/data/local/node-termux/data/data/com.termux/files/usr/bin:/data/local/hermes-venv/bin:/data/data/com.termux/files/usr/bin:/system/bin:/vendor/bin
    export LD_LIBRARY_PATH=/data/data/com.termux/files/usr/lib:/data/local/node-termux/data/data/com.termux/files/usr/lib
    export LD_PRELOAD=/data/data/com.termux/files/usr/lib/libpython3.14.so
    export TMPDIR=/data/local/tmp
    sh /data/local/hermes-home/scripts/preflight_venv.sh
    nohup /data/local/hermes-venv/bin/hermes gateway run > /data/local/tmp/hermes.log 2>&1 &
  fi
  # webui (port 3000) — chi revive khi file web/server.py ton tai
  if [ -f /data/local/hermes-home/web/server.py ] \
     && ! pgrep -f "web/server.py" > /dev/null 2>&1
  then
    sh /data/local/hermes-home/scripts/webui.sh start > /dev/null 2>&1
  fi
  if ! pgrep -f com.tailscale.ipn > /dev/null 2>&1
  then
    monkey -p com.tailscale.ipn -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1
  fi
  sleep 300
done
