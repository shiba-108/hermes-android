---
name: sys-status
description: Check Hermes system status on OnePlus 11R, read-only, no restart
version: 1.1.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [sys, status, monitoring]
    related_skills: [sys-logs, sys-restart, sys-maintenance]
---

## When to Use

- User nói check hệ thống, status, kiểm tra máy.

## Steps

When user says check he thong, status, kiem tra may, do:

1. Run pgrep -f doh-proxy
2. Run pgrep -f gateway
3. Run pgrep -f com.tailscale.ipn
4. Run timeout 5 ping -c 1 google.com
5. Run pgrep -f 05-watchdog

Return table with PID or NOT RUNNING for each, plus ping result.

Do NOT run kill, rm, pkill, or restart anything without asking user first.

## Pitfalls

- `pgrep -af <pattern>` trên host này thường khớp cả shell snapshot của chính lệnh terminal (cmdline dài chứa pattern) → PID rác. Dùng `pgrep -f <pattern>` (không `-a`), và khi cần args dùng `ps -eo pid,etime,args | grep -E '<pattern>' | grep -v 'bash -c'` rồi `cut -c1-160`.
- `pgrep -f "hermes gateway run"` KHÔNG khớp tiến trình gateway được khởi động qua `hermes gateway restart` (argv giữ nguyên `... gateway restart`). Kiểm tra bằng `pgrep -f "gateway run|gateway restart"` hoặc đối chiếu `gateway.sock` + port.
- Ping OK không có nghĩa gateway khỏe: luôn đối chiếu thêm dòng `Connected to Telegram` / `Gateway running` trong `logs/gateway.log`.
