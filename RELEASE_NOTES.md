# v0.1.0

Initial release of ADB Wi-Fi Connect Helper for macOS.

## Highlights

- Discovers Android wireless-debugging connection ports over Bonjour/mDNS.
- Supports first-time pairing and direct connection to a known `IP:PORT`.
- Locates `adb` from common Android Studio and SDK installations.
- Supports non-interactive use, configurable positive scan durations, and adb
  server restarts.

## Release asset

Attach the executable `adb-wifi-connect.command` file to the GitHub release.
Users can then install v0.1.0 with the command documented in the README.

## Validation before publishing

```bash
bash -n adb-wifi-connect.command tests/test.sh
bash tests/test.sh
shellcheck --shell=bash adb-wifi-connect.command tests/test.sh
```

The macOS Bonjour/mDNS discovery and real Android-device connection path must be
verified manually when suitable hardware is available; it is not covered by CI.
