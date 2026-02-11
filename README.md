# Claude Usage

A native macOS menu bar app that displays your Claude AI usage quota in real-time.

![macOS](https://img.shields.io/badge/macOS-15.7+-blue)
![Swift](https://img.shields.io/badge/Swift-5-orange)

## Features

- **Menu bar icon** that fills up like a battery indicator as your quota is consumed
- **Optional percentage text** displayed next to the icon
- **Color-coded states**: blue (normal), orange (using paid credits), gray (out of quota)
- **Popover dashboard** showing session, weekly, and Opus usage with progress bars and reset countdowns
- **Extra usage credits** tracking with currency display (USD/GBP/EUR)
- **Auto-refresh** every 5 minutes
- **Secure credential storage** via macOS Keychain

## Setup

1. Build and run the app in Xcode
2. On first launch, the setup window will ask for two values:

   **Organization ID** — Go to [claude.ai](https://claude.ai) → Settings. Copy the UUID from the URL.

   **Session Key** — Open your browser's dev tools on claude.ai → Application → Cookies. Find the `sessionKey` cookie (starts with `sk-ant-`).

3. Credentials are stored in your macOS Keychain and never leave your machine.

## Building

Requires Xcode and macOS 15.7 (Sequoia) or later. No external dependencies.

```
open claude-usage.xcodeproj
```

Build and run with Cmd+R.
