# Contributing

Contributions are welcome. Keep changes focused and preserve the menu-bar-only, read-only design of the application.

## Development

1. Install Xcode and XcodeGen (`brew install xcodegen`).
2. Run `./build.sh test`.
3. Run `./build.sh debug` and exercise the menu-bar UI.
4. Do not commit generated Xcode projects, build products, signing configuration, credentials, or notarization artifacts.

## Adding a UPS Profile

Run `./build.sh compatibility --diagnostic` and include its output in a device-support issue. The report intentionally omits USB serial numbers.

A device profile belongs in `UPSMenu/UPSDeviceProfile.swift`. Do not mark a profile supported from usage names alone: verify its vendor/product ID, report IDs, units, scaling, required values, and behavior on line power and battery power. Add focused tests for every new mapping.

## Pull Requests

- Explain the user-visible behavior and compatibility impact.
- Include test results from `./build.sh test`.
- Do not include unrelated formatting or generated files.
- Confirm new UI remains usable when the UPS is disconnected.
