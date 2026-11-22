# Результаты host-проверок и статус Android 14

## Текущий результат

На Linux x86_64 прогнан `python3 tests/no_root_harness.py`: **10/10 PASS** на рабочем дереве интеграционной ветки, которое включает исправления V2 и upstream `e3adac6`. Это тесты host с временными файлами, заглушками и localhost; они не являются тестом Android.

Дополнительно: `sh -n` прошёл для всех shell-скриптов в рабочем дереве, `ast.parse` прошёл для 3 Python-файлов, `git diff --check` прошёл, конфликтных маркеров нет, `service.d/` не менялся относительно общей базы веток.

**Android 14/API 34 остаётся BLOCKED; Android/Termux-тесты NOT RUN. PASS на Android не заявляется.** В Sandbox отсутствуют `/dev/kvm`, `adb`, Android Emulator/SDK tools и QEMU; предыдущая попытка запуска через TCG не завершилась. OnePlus 11R не использовался.

## Результаты harness

| Проверка | Результат | Что именно проверено |
|---|---|---|
| Shell/Python syntax | PASS | Shell-файлы проверены `sh -n`; Python проверен синтаксически. Linux-only проверка синтаксиса. |
| Стандартный bind host | PASS | С моками проверены значения по умолчанию для root и non-root; сервер не открывался на внешнюю сеть. |
| Отсутствует Python | PASS | Installer прекращает работу до записи установочных файлов; использован временный PATH. |
| Нет Git, когда нужен clone | PASS | Installer прекращает работу, если требуется clone, а Git недоступен. Clone и сеть не использовались. |
| Lock package-name payload | PASS | Искусственный payload в имени пакета не исполняется; pip и venv подменены заглушками. |
| Root lock trust boundary | PASS | В симуляции UID 0 недоверенный путь lock отвергнут. Права и системные файлы не менялись. |
| Web UI custom venv | PASS | Локальные заглушки подтвердили использование заданного `HERMES_VENV`; тестовые HTTP-запросы шли только на localhost. |
| `start-manual.sh` передаёт custom paths | PASS | Временная среда подтвердила передачу путей helper-у watchdog. |
| `start-manual.sh` под UID 0 | PASS | Helper отказывает при UID 0. |
| Python syntax в Web UI server | PASS | Проверена синтаксическая корректность Python-файла; gateway/API не запускались. |

Общий вывод harness: **10/10 PASS** на Linux. Никакие тесты не подтверждают установку на Android, работу Shizuku/rish, перезагрузку устройства, Telegram-соединение, запросы к модели или uptime.

## Android 14 / API 34

| Hạng mục | Trạng thái | Ghi chú |
|---|---|---|
| Boot AVD Android 14 / API 34 | BLOCKED | Sandbox не имеет KVM, emulator, SDK tools и QEMU; предыдущая попытка запуска TCG не завершилась. |
| Установка Termux no-root | NOT RUN | Нет Android/Termux для установки; installer проверялся на host с заглушками. |
| Reboot и автозапуск | NOT RUN | Android emulator не запускался. |
| Watchdog revival на Android | NOT RUN | На устройстве не проверялось. |
| Shizuku, rish и Private DNS | NOT RUN | Только моделирование shell-команд в тестах ветки; это не Android/Shizuku-тест. Android Private DNS использует DoT, не DoH. |
| Telegram/gateway/model | NOT RUN | Нет реальных credentials и подключения к API/provider. |
| Видео и live Telegram screenshots | NOT AVAILABLE | Реальная съёмка не выполнялась; SVG в репозитории — mockup. |

Android можно пометить PASS только после реальной проверки на Android 14/API 34: зафиксировать версии Android и Termux, установку, reboot, проверку автозапуска, остановку процесса и наблюдение за watchdog, затем сохранить локальные логи и реальный Telegram-результат.

## Журналы

- [Текущий интеграционный прогон и предыдущие проверки](test-logs/review-feat-no-root-2026-11-22.log)
- [Базовый Linux host log](test-logs/linux-host-2026-11-22.log)
