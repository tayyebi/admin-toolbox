# Admin Toolbox

Mobile-first infrastructure operations for Linux servers. Manage, monitor and
automate a fleet over SSH from an Android phone, with nothing installed on the
managed hosts.

Everything is local: the inventory, the credentials and the metrics live in a
SQLite database on the device. There is no backend, no account, and no
telemetry.

## Features

**Credential vault** — SSH keys and passwords encrypted with AES-256-GCM under
a key derived from your master password (PBKDF2-HMAC-SHA256, 210k iterations).
Import an existing key, or generate an RSA key pair on the device. Export the
public key or install it into a host's `authorized_keys` in one step.

**Host inventory** — Hosts, groups, tags and notes. Each host is attached to a
vault credential, and a Test Connection button verifies the whole path before
you save.

**Host key pinning** — Server keys are pinned on first use. A changed key
blocks the connection and shows both fingerprints rather than reconnecting
silently.

**Terminal** — A real PTY with full ANSI and 256-colour support, resize,
copy/paste, scrollback, and one-tap insertion from the command library.

**Files** — SFTP browsing, upload, download, rename, delete, chmod and an
editor for small text files.

**Agentless monitoring** — Nine collectors gather CPU, memory, disk, network,
process, service, Docker, system and security metrics over SSH. Metrics are
charted per host and aged out on a retention schedule.

**Alerting** — Rules evaluate after each collection. An alert fires once,
notifies locally, auto-resolves on recovery, and can be acknowledged or
silenced.

**Automation** — Multi-step procedures across many hosts, with variables,
dry run, exit-code gating, rollback on failure and full run history.

**Audit log** — Every change, connection and secret reveal is recorded in a
hash-chained log, so tampering is detectable.

## Security model

What the app guarantees, and what it does not:

- The master password is never stored. It derives a key-encryption key that
  wraps a random data-encryption key; only the wrapped key is at rest, in
  Android's `EncryptedSharedPreferences`. **There is no recovery** — forget the
  password and the stored credentials are gone.
- The data key exists in plaintext only in memory, only while unlocked. The
  app re-locks after a configurable time in the background.
- Biometric unlock is a convenience gate over the same stored key, not a
  second independent secret.
- `FLAG_SECURE` is on by default, keeping the app out of screenshots and the
  task-switcher preview.
- Cloud backup and device-to-device transfer are disabled for app data.
- A rooted device, or one with an unlocked bootloader, defeats all of this.
  The threat model is a lost or stolen phone, not a compromised OS.

## Tech stack

Flutter 3.27 · Riverpod · GoRouter · sqflite · dartssh2 · xterm · pointycastle
· fl_chart · Inter + JetBrains Mono

## Getting started

```bash
flutter pub get
flutter run
```

On first launch you will be asked to create a vault. Then add a credential
(Vault → +), add a host, and attach the credential to it — a host with no
credential cannot connect and will show as `unknown`.

## Building

```bash
flutter build apk --release       # sideload
flutter build appbundle --release # Play Store
```

Release builds are minified and obfuscated. Keep the `build/symbols` output for
any build you distribute, or its crash reports cannot be symbolicated.

## Architecture

```
lib/
  main.dart                  Entry point, error zone, startup failure screen
  app.dart                   MaterialApp, theme mode
  core/
    crypto/                  Envelope encryption, SSH key service, wire formats
    database/                SQLite schema and migrations
    security/                App lock, biometric gate, FLAG_SECURE
    settings/                Persisted preferences
    theme/                   Colour tokens, typography, light and dark themes
    utils/                   Logging, formatting, JSON helpers
  data/
    models/                  Plain data classes with map serialisation
    repositories/            Data access
    transport/               SSH and SFTP, host key verification, pooling
  modules/
    monitoring/              Collectors and the collection loop
    alerting/                Rule evaluation and notifications
    automation/              Procedure execution and rollback
  providers/                 Riverpod wiring
  ui/
    screens/                 One directory per feature
    widgets/                 Shared components
    shell/                   Navigation shell and lifecycle
```

## Testing

```bash
flutter analyze
flutter test
```

Unit tests cover serialisation round-trips, the crypto primitives and wire
formats, alert condition evaluation, formatting helpers and theming. Transport
and vault flows need a real device and a real server; see the manual checks
below.

Against a disposable target:

```bash
docker run -d --name sshtest -p 2222:22 \
  -e USER_NAME=admin -e PASSWORD_ACCESS=true -e USER_PASSWORD=testpass \
  linuxserver/openssh-server
```

1. Create the vault; force-quit and reopen to confirm the lock screen.
2. Generate a key, install the public key on the container, connect.
3. Confirm the host key prompt appears once, then not again; change the pinned
   fingerprint and confirm the next connection is blocked.
4. Open the terminal, run `top` and a 256-colour test, rotate the device.
5. Upload and download a file, compare checksums.
6. Start collection, set a CPU rule at 1%, confirm one alert and one
   auto-resolution.
7. Toggle the system light/dark setting and confirm the app follows.

## CI

`.github/workflows/build-apk.yml` runs formatting, analysis and tests on every
push and pull request.

Artifacts are built only when there is something to install: a `v*` tag builds
a signed APK and App Bundle and publishes a GitHub release. A manual run
(Actions → CI → Run workflow) builds them on demand, which is the way to get a
test build off a branch. Ordinary pushes to `main` stop after the checks.

Signing secrets, if configured:

| Secret | Purpose |
| --- | --- |
| `STORE_FILE_B64` | Base64-encoded keystore |
| `STORE_PASSWORD` | Keystore password |
| `KEY_PASSWORD` | Key password |
| `KEY_ALIAS` | Key alias |

Without them CI generates a throwaway key so the build still runs. Those
artifacts are not distributable — a build signed with a different key cannot
update an existing install.

## Known limitations

- **Android only.** There is no `ios/` project.
- **Key generation is RSA only.** `dartssh2` exposes no key generation, and
  writing the `openssh-key-v1` container by hand for Ed25519 was not worth the
  risk. Ed25519 keys generated with `ssh-keygen` import and work normally.
- **Collectors assume Linux.** They read `/proc`, `free`, `df` and `systemctl`.
- **Monitoring runs only while the app is open.** There is no background
  service or push delivery.
- **Fingerprints are recorded only when you supply the public key.** Importing
  a private key alone validates it, but the vault cannot derive the public half
  without depending on package internals.

## License

Private.
