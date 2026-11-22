# Security review — hermes-android V2 beta

## Scope and status

This is a source-level review of the V2 no-root additions and selected related installer, Shizuku, Web UI, and existing Magisk paths. It is not a full penetration test or Android security certification. Upstream Hermes Agent and third-party dependencies are outside the scope of this repository's changes.

The Linux host harness passed **10/10** on the integration worktree. It uses temporary files, stubs, and localhost; it does not verify Android, Termux, Magisk, Shizuku/rish, Telegram, or provider behavior. Android 14/API 34 remains BLOCKED / NOT RUN. No phone, including Shiba's OnePlus 11R, was used.

A repository scan covered 37 tracked/unignored files and found no known GitHub token, private-key, or AWS-key patterns. The forbidden-path scan found no `.env`, `auth.json`, `sessions/`, `config.yaml`, or `log_hash_salt` in the scanned file set. This pattern scan is useful but is not a guarantee that every possible secret format was detected.

## Release-relevant findings

### High: Existing root/Magisk scripts trust Termux paths

The existing `service.d/` scripts load commands, libraries, and scripts from Termux/Hermes paths through `PATH`, `LD_LIBRARY_PATH`, and `LD_PRELOAD`. If a less-privileged Termux process can modify something later executed or loaded by root, the next boot or watchdog run may execute that modified code as root. The installer copies these scripts under root when it detects root + Magisk.

This risk is **not fixed** by the no-root additions. `service.d/` is unchanged in this integration. Do not describe the Magisk path as security-audited or equivalent to the no-root path; review and harden it separately before recommending privileged unattended use.

### High: Root-mode ADB and network behavior

The existing root scripts configure ADB-over-TCP on port 5555 and add an `iptables` redirect for DNS proxying. Their Android/device behavior and exposure were not tested for this beta. Keep these effects clearly documented; do not enable the root path on an untrusted network.

### High: Installer source is not pinned or signature-verified

The installer clones the current `hermes-android` branch when run from a pipe and clones upstream Hermes Agent without pinning a commit or verifying a signature/checksum. This beta did not add source pinning. Avoid treating `curl | bash` under root as a verified supply chain.

### High: Web UI has no authentication

The Web UI includes an unauthenticated API. The no-root launcher defaults to `127.0.0.1`; the root launcher defaults to `0.0.0.0`, and `WEBUI_HOST` can override the bind address. Do not expose this UI to an untrusted network or the public Internet. A private network or firewall reduces exposure but does not add authentication.

## V2 no-root and Shizuku behavior

- `scripts/no-root-watchdog.sh` is Termux-only and manages only the Hermes gateway process it starts. It does not supervise Telegram connectivity, Tailscale, Web UI, DNS, Android package state, or Doze.
- `scripts/start-manual.sh` delegates to that watchdog and refuses UID 0. Host regression tests cover custom path forwarding and the UID 0 refusal.
- Termux:Boot is opt-in; installer does not register a boot hook automatically. Android reboot behavior has not been tested.
- Shizuku operations require explicit commands through `rish`. They do not grant root. Package changes are limited to a specific third-party package; the helper does not claim to undo a pre-existing disabled state.
- Android Private DNS is a device-wide DNS-over-TLS (DoT) setting, not DNS-over-HTTPS (DoH). No transparent system-wide DoH implementation is claimed.
- Root without Magisk has no project-configured boot hook in this beta. The no-root manual-start helper explicitly rejects UID 0.

## Checks performed

- `python3 tests/no_root_harness.py`: **10/10 PASS** on Linux x86_64 with stubs/temp files/localhost.
- `sh -n` on all shell scripts: PASS.
- `ast.parse` on 3 Python files: PASS.
- `git diff --check`: PASS.
- Conflict-marker scan: clean.
- `service.d/` comparison with the merge base: unchanged.
- Secret-pattern and forbidden-path scans: clean as described above.

No Android emulator/device test, live Telegram exchange, provider request, video capture, or real Shizuku/Magisk operation was performed. The checks above do not establish Android compatibility, continuous uptime, or root-equivalent behavior.
