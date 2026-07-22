# Admin Toolbox

Mobile-first Infrastructure Operations Platform for Linux server administration.

## Overview

Admin Toolbox enables administrators to securely manage, monitor, and automate operations across hundreds or thousands of servers without requiring any software installation on the managed hosts.

## Features

- **Infrastructure Inventory** — Manage hosts, groups, tags, and metadata
- **Credential Vault** — Encrypted credential storage with hardware-backed encryption
- **Agentless Monitoring** — Collect metrics via SSH without installing agents
- **Terminal** — Interactive SSH terminal with ANSI support
- **File Management** — Browse, upload, download, and edit remote files
- **Automation Library** — Reusable operational procedures
- **Command Library** — Frequently used commands with variables
- **Incident Center** — Track and resolve operational incidents
- **Alert Engine** — Rule-based monitoring with notifications
- **Audit Log** — Immutable audit records for all operations

## Tech Stack

- **Framework:** Flutter 3.27.4
- **Language:** Dart 3.2+
- **State Management:** Riverpod
- **Database:** SQLite (sqflite)
- **Navigation:** GoRouter
- **Charts:** fl_chart
- **Encryption:** encrypt + pointycastle
- **SSH:** dartssh2

## Getting Started

```bash
flutter pub get
flutter run
```

## Building

```bash
# Debug APK
flutter build apk --debug

# Release APK
flutter build apk --release
```

## CI/CD

Automated builds via GitHub Actions on tag pushes (`v*`) and manual dispatch.

GitHub Secrets required for release signing:
- `STORE_FILE_B64` — Base64-encoded keystore
- `STORE_PASSWORD`
- `KEY_PASSWORD`
- `KEY_ALIAS`

## Architecture

```
lib/
  main.dart              — Entry point
  app.dart               — App widget with Riverpod
  core/
    database/            — SQLite database
    crypto/              — Encryption service
    theme/               — Dark theme
    utils/               — Extensions & utilities
  data/
    models/              — Data models
    transport/           — SSH, SFTP transport abstraction
    repositories/        — Data access layer
  providers/             — Riverpod providers
  modules/
    monitoring/          — Metric collectors & monitoring service
  ui/
    screens/             — App screens
    widgets/             — Reusable widgets
    shell/               — Navigation shell
```

## License

Private
