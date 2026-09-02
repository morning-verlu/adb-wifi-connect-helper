# ADB Wi-Fi Connect Helper

[简体中文](README.zh-CN.md)

A small macOS helper for the Android wireless-debugging state where pairing
succeeds, but Android Studio still cannot see or deploy to the device.

The helper discovers the device's current `_adb-tls-connect._tcp` service and
runs `adb connect` against the advertised connection port.

## Why this helper exists

Android wireless debugging has two separate steps:

```text
adb pair      authorizes the computer
adb connect   connects the device for installs and debugging
```

The pairing-code screen and the main Wireless debugging screen usually expose
different ports. A successful command such as:

```bash
adb pair 192.168.1.20:36451
```

does not mean that `192.168.1.20:36451` is the port Android Studio should use.
The actual connection may be advertised as, for example:

```bash
adb connect 192.168.1.20:45109
```

This helper finds that second port automatically.

## Requirements

- macOS
- Android Studio or Android SDK Platform-Tools (`adb`)
- Android 11 or newer
- The Mac and Android device on the same local network
- **Developer options > Wireless debugging** enabled on the device

## Install

### Download the v0.1.0 release

```bash
curl --fail --location --output adb-wifi-connect.command \
  https://github.com/morning-verlu/adb-wifi-connect-helper/releases/download/v0.1.0/adb-wifi-connect.command
chmod +x adb-wifi-connect.command
./adb-wifi-connect.command
```

### Download the latest source

```bash
curl --fail --location --output adb-wifi-connect.command \
  https://raw.githubusercontent.com/morning-verlu/adb-wifi-connect-helper/main/adb-wifi-connect.command
chmod +x adb-wifi-connect.command
./adb-wifi-connect.command
```

### Clone the repository

```bash
git clone https://github.com/morning-verlu/adb-wifi-connect-helper.git
cd adb-wifi-connect-helper
chmod +x adb-wifi-connect.command
./adb-wifi-connect.command
```

You can also double-click `adb-wifi-connect.command` in Finder after making it
executable.

## Usage

For a computer that is already paired with the phone, run:

```bash
./adb-wifi-connect.command --skip-pair
```

The helper will:

1. Locate `adb`.
2. Browse for `_adb-tls-connect._tcp` services with macOS `dns-sd`.
3. Resolve the device's current connection port.
4. Run `adb connect` for each discovered target.
5. Print `adb devices -l`.

A connected device looks similar to:

```text
192.168.1.20:45109 device product:PHY110 model:PHY110
```

### Pair for the first time

On the phone, open **Developer options > Wireless debugging > Pair device with
pairing code**, then run:

```bash
./adb-wifi-connect.command --pair 192.168.1.20:36451 868723
```

After pairing, return to the main Wireless debugging screen. The helper will
continue by discovering the separate connection port.

### Connect to a known port

If the main Wireless debugging screen already shows the connection address:

```bash
./adb-wifi-connect.command --connect 192.168.1.20:45109
```

### Options

```text
--pair IP:PORT [CODE]   Pair with the phone pairing-code page first.
--connect IP:PORT       Connect to a known wireless-debugging port.
--skip-pair             Do not ask for pairing information.
--restart-adb           Restart the adb server before connecting.
--seconds N             Scan for N seconds; N must be a positive integer.
-y, --yes               Do not prompt for input.
-h, --help              Show help.
```

For example, increase the scan window on a slow network:

```bash
./adb-wifi-connect.command --seconds 8 --skip-pair
```

## Troubleshooting

If `adb devices -l` shows an entry ending in `device`, the connection is ready
even if Android Studio has not refreshed yet. Close the Wi-Fi pairing dialog,
refresh the device selector, and restart Android Studio if necessary.

If no target is found:

- Keep the phone unlocked on the main Wireless debugging screen.
- Confirm that the phone and Mac are on the same network.
- Disable client isolation or guest-network isolation on the access point.
- Retry with a longer scan, such as `--seconds 8`.
- Use `--connect IP:PORT` with the address shown on the phone.

## Development and verification

```bash
bash -n adb-wifi-connect.command
bash tests/test.sh
shellcheck --shell=bash adb-wifi-connect.command tests/test.sh
```

CI checks shell syntax, help output, invalid `--seconds` values, and ShellCheck.
The full discovery and connection flow requires macOS, Bonjour/mDNS, and a real
Android device, so that path is not exercised by CI.

## License

[MIT](LICENSE)
