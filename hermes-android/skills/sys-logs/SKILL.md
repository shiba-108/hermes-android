---
name: sys-logs
description: Use when user asks xem log gateway. tail log, read-only.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [sys, logs, gateway, monitoring]
    related_skills: [sys-status]
---

## When to Use

- User says xem log, check log, log gateway.
- Cần đọc log gateway hoặc errors.log.

## Steps

When user says xem log, check log, log gateway:

1. Run `tail -n 50 /data/local/hermes-home/logs/gateway.log`
2. If user asks lỗi/errors: also `tail -n 30 /data/local/hermes-home/logs/errors.log`
3. Nếu log dài, trả về 20-30 dòng đáng chú ý nhất (lỗi, cảnh báo, restart), không dán nguyên 50 dòng.

Chỉ đọc. KHÔNG kill, restart, rm, pkill. Nếu cần thao tác sửa thì hỏi user trước.
