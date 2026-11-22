# hermes-android

Bộ script + skill để giữ Hermes gateway sống trên điện thoại Android (OnePlus 11R, Termux + Magisk).

## Cấu trúc

```
hermes-android/
├── README.md
├── BI-KIP.md                  # bí kíp vận hành + pitfalls
├── install.sh                 # cài service.d + scripts (idempotent)
├── service.d/                 # Magisk service.d (chạy root sau mỗi boot)
│   ├── 02-adbd.sh
│   ├── 03-nowake.sh           # chống ngủ / chống battery optimize
│   ├── 04-doh.sh              # doh-proxy + iptables NAT 53
│   ├── 05-watchdog.sh         # nuôi lại doh/gateway/tailscale
│   └── hermes.sh              # khởi động gateway
├── scripts/
│   ├── preflight_venv.sh      # kiểm tra/tự sửa dependency venv trước khi chạy
│   └── make_lock.py           # sinh lock từ uv.lock (resolve, không build)
├── skills/
│   ├── sys-status/SKILL.md
│   └── sys-logs/SKILL.md
└── locks/
    ├── venv-requirements.android.lock   # 59 gói khả dụng trên Android
    └── venv-requirements.lock           # freeze 28 gói đang chạy
```

## Cài đặt

```sh
sh install.sh
```

Đỏ hết `service.d/` vào `/data/adb/service.d/` (tự `.bak` nếu đã có), `scripts/` vào
`/data/local/hermes-home/scripts/`, `locks/` vào `backups/`.

## Vận hành

- Check: `check hệ thống` → skill `sys-status`.
- Log: `xem log` → skill `sys-logs`.
- Restart: `restart gateway` → skill `sys-restart` (luôn hỏi Yes/No trước).
- Dọn/đánh giá: xem skill `sys-maintenance`.

## Nguyên tắc

- Chỉ đọc trước, luôn hỏi Yes/No trước khi sửa file hệ thống / restart / xóa.
- Không bao giờ `pm uninstall`; chỉ `pm disable-user --user 0`.
- Không đụng: Tailscale, Termux (kể cả `termux.api`/`termux.boot`), Play Services, Gboard.
- Sửa script đang chạy → phải restart tiến trình để nạp code.
