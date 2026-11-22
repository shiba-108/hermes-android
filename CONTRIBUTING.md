# Contributing

Thanks for helping improve `hermes-android`. Keep changes reproducible, security-conscious, and aligned with the code that exists today.

## Before opening a pull request

- Explain the user problem and keep the change focused.
- For device reports, include the device/model, Android version, root method (or “non-root Termux”), relevant project revision, the exact commands tried, and the observed result. Redact tokens, account identifiers, private IPs, message contents, and other sensitive data from logs.
- Distinguish **tested**, **reported by someone else**, **experimental**, and **not tested**. Do not claim Android PASS, 24/7 uptime, root equivalence, free/unlimited models, or reliable recovery without direct evidence.
- Keep documentation synchronized with installer paths, service scripts, and real behavior. Mark manual workarounds as manual; do not present them as installer-supported features.
- Never commit `.env`, credentials, private config, session data, private keys, unredacted logs, or plaintext backups. Use placeholders such as `<YOUR_TOKEN>` in examples.
- Review security effects before changing network/debugging behavior. In particular, document any ADB-over-TCP, firewall, web UI, or backup changes and their exposure risks.

## Local checks

Run the POSIX shell syntax check for the shell scripts and check the patch for whitespace errors:

```sh
for f in install.sh scripts/*.sh service.d/*.sh; do
  sh -n "$f" || exit 1
done
git diff --check
```

These checks do **not** test Android boot behavior, Magisk, Termux:Boot, Shizuku, background execution, network connectivity, provider credentials, or model availability. Report device-level verification only when it was actually performed, and include the device/OS and exact test steps.

## Scope and licensing

Small, reviewable contributions are easiest to validate. Do not add generated media or claim that an illustration is a real capture. Contributions are subject to the repository's [MIT license](LICENSE).

---

# Đóng góp

Cảm ơn bạn đã giúp cải thiện `hermes-android`. Hãy giữ thay đổi có thể tái hiện, chú ý bảo mật và khớp với mã nguồn hiện tại.

## Trước khi mở pull request

- Nêu vấn đề người dùng gặp và giữ thay đổi trong phạm vi rõ ràng.
- Với báo cáo thiết bị, ghi model máy, phiên bản Android, phương thức root (hoặc “Termux không root”), revision liên quan, lệnh chính xác đã chạy và kết quả quan sát được. Che token, định danh tài khoản, IP riêng, nội dung tin nhắn và thông tin nhạy cảm khác khỏi log.
- Phân biệt rõ **đã test**, **người khác báo lại**, **đang thử nghiệm** và **chưa test**. Không khẳng định Android PASS, uptime 24/7, tương đương root, model miễn phí/không giới hạn hay tự phục hồi đáng tin cậy nếu chưa có bằng chứng trực tiếp.
- Giữ tài liệu khớp đường dẫn trong installer, service scripts và hành vi thật. Ghi rõ workaround thủ công; đừng mô tả như tính năng được installer hỗ trợ.
- Không commit `.env`, credential, cấu hình riêng tư, dữ liệu phiên, private key, log chưa che hoặc bản sao lưu chưa mã hóa. Dùng placeholder như `<YOUR_TOKEN>` trong ví dụ.
- Xem xét tác động bảo mật trước khi đổi hành vi mạng/gỡ lỗi. Đặc biệt phải ghi rõ rủi ro lộ mạng của ADB-over-TCP, firewall, web UI hoặc thay đổi sao lưu.

## Kiểm tra cục bộ

Chạy kiểm tra cú pháp POSIX shell cho shell script và kiểm tra lỗi whitespace trong patch:

```sh
for f in install.sh scripts/*.sh service.d/*.sh; do
  sh -n "$f" || exit 1
done
git diff --check
```

Các bước này **không** kiểm tra hành vi boot Android, Magisk, Termux:Boot, Shizuku, chạy nền, kết nối mạng, credential provider hay khả năng truy cập model. Chỉ báo đã xác minh trên thiết bị nếu thực sự đã làm, kèm thiết bị/OS và từng bước test chính xác.

## Phạm vi và giấy phép

Thay đổi nhỏ, dễ review sẽ dễ xác minh hơn. Không thêm media tạo sinh hoặc mô tả hình minh họa như ghi hình thật. Đóng góp tuân theo [giấy phép MIT](LICENSE).
