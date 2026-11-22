# Android device status and test notes

## V2 beta verification status

No Android device or Android emulator was verified for this V2 beta. Android 14/API 34 testing is BLOCKED / NOT RUN; see [`../TESTING.md`](../TESTING.md) and the saved host logs. The Linux host harness is not evidence of Android compatibility, Telegram connectivity, reboot recovery, or 24/7 uptime.

No physical phone, including Shiba's OnePlus 11R, was used for this release work.

## Intended environment

- Android with Termux; behavior can vary by Android release and device manufacturer.
- Root is not required for the Termux no-root path.
- Magisk `service.d/` is a separate root-only path and has not been revalidated for this beta.
- Shizuku is optional and only performs the explicitly requested operations documented in [`NO-ROOT.md`](NO-ROOT.md). Android Private DNS uses DoT, not DoH.

These are project targets and code paths, not claims that a particular device or Android version has passed testing. Do not rely on the gateway for continuous availability until the exact device, ROM, Termux version, reboot behavior, and recovery behavior have been tested.

## What to include in a device report

For a reproducible community report, include:

- Device model and Android/ROM version.
- Termux and Termux:Boot versions and installation source.
- Root/Magisk/Shizuku configuration, if used.
- The exact install and start commands, with secrets removed.
- Whether the gateway was verified, whether a real Telegram exchange succeeded, and what happened after reboot or process termination.
- Logs with tokens, personal data, hostnames, and private paths removed.

Mark mock, host-only, and unverified reports clearly. Do not describe a device as tested or stable based only on another device, a mocked test, or a running process.

## Root and device safety

Rooting is optional and device-specific. Bootloader unlocking or flashing can erase data or make a device unusable; use the manufacturer's and Magisk's current instructions for the exact model. Do not use Shiba's OnePlus 11R for development or testing.

The existing Magisk scripts include system-level network and power-management changes. Review `service.d/` and [`../SECURITY.md`](../SECURITY.md) before opting into the root path. The Web UI has no authentication; root mode currently binds to all interfaces by default.

## Contributing a test report

Open a pull request with reproducible steps and non-sensitive logs. Keep host-test results separate from Android/device results, and say plainly when a step was blocked or not run. See [`../CONTRIBUTING.md`](../CONTRIBUTING.md).
