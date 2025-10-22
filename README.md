# HotkeyService

HotkeyService is a macOS SwiftUI application scaffold configured for macOS 13 and newer. The project is set up with a shared Swift Package for future modular development and includes a placeholder dependency on the [Down](https://github.com/iwasrobbed/Down) Markdown renderer.

## Requirements

- macOS 13.0 or newer (Intel or Apple silicon)
- Xcode 15 or newer (Swift 5.9 toolchain)

## Project Layout

```text
HotkeyService.xcodeproj/      # Xcode project for the macOS SwiftUI app
HotkeyService/                # App sources, assets, and entitlements
Package.swift                 # Swift Package Manager manifest
Sources/                      # Shared Swift package sources
Tests/                        # Unit tests for the shared package
```

The Xcode target uses the SwiftUI lifecycle, treats warnings as errors, and enables the Hardened Runtime for release builds. The Swift package exposes the `HotkeyServiceKit` module and links the Down package as a placeholder dependency.

## Getting Started

1. Open `HotkeyService.xcodeproj` in Xcode.
2. Select the `HotkeyService` scheme.
3. Choose the "My Mac" destination and press **Cmd+R** to build and run.

Alternatively, developers can build the Swift package modules directly:

```bash
swift build
```

> The first time you open the project, Xcode will resolve the Down dependency through Swift Package Manager.

## Required macOS Permissions

To support global hotkey capture and background services, the application will ultimately require elevated permissions:

- **Accessibility** – Needed to observe and respond to global keyboard shortcuts.
- **Input Monitoring** – Required to capture keyboard events outside the application.
- **Automation / Services** – If the app triggers other applications or system services, the appropriate automation permissions must be granted.

During development these capabilities are disabled by default. As features are implemented, update the entitlements and document any additional permission prompts here.

## Icons & Assets

Placeholder application and menu bar icons are included in the asset catalog. Replace them with production artwork before release.

## Contributing

- Keep warnings at zero – the project is configured to treat warnings as errors.
- Target macOS 13 or newer for all modules.
- Prefer adding shared functionality to the `HotkeyServiceKit` Swift package to encourage modular design.
