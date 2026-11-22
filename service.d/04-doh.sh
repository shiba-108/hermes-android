#!/system/bin/sh
sleep 5
setsid /data/data/com.termux/files/usr/bin/python /data/data/com.termux/files/home/doh-proxy.py &
sleep 2
iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-port 53
