# Changelog

## 2.3.0

- Added persistent branding and support configuration stored outside the replaceable template directory.
- Added the Persian `homa-sub` manager with status, configure, update, backup, restore, doctor, and uninstall commands.
- Added an optional post-install configuration wizard and non-interactive configuration flags.
- Added safe updates that preserve settings, validate per-file backup checksums, keep three recent copies, and roll back failed installs or restarts.
- Added usage forecasting with daily average, estimated quota depletion, and 80/90 percent alerts.
- Added smart renewal prompts for limited, expired, disabled, near-expiry, and high-usage accounts.
- Added configurable Telegram renewal drafts without exposing the subscription link or configurations.
- Added a safe diagnostic report with account/device state while excluding URLs, tokens, and proxy configs.
- Hardened the online installer with exact checksum metadata validation, ZIP traversal, entry-count, expanded-size, and symlink checks.
- Added migration of the previous inline brand/support/channel settings on first v2.3 installation.
- Expanded automated coverage to 22 scenarios, including the complete install/configure/update/backup/restore/rollback/migration/uninstall lifecycle and hostile release artifacts.
- Reverified the Marzban subscription endpoints and V2Box store listings against current official sources.

## 2.2.0

- Added a one-line online installer for new installations and template updates.
- Added automatic release download, SHA-256 verification, extraction, and handoff to the rollback-safe installer.
- Added automatic installation of `unzip` on supported Debian, Ubuntu, Fedora, RHEL, and CentOS servers when needed.
- Updated Persian installation documentation with the one-line command and its safety workflow.
- Added regression coverage for the online installer's syntax, pinned version, official repository path, checksum verification, and local installer handoff.

## 2.1.0

- Added V2Box to the Android client catalog while preserving its iOS/iPadOS guide.
- Added platform-specific official Google Play and App Store download links.
- Updated the V2Box tutorial for subscription import, refresh, ping testing, and connection.
- Added regression assertions for V2Box visibility and download routing on both mobile platforms.

## 2.0.0

- Rebuilt the entire interface with a new responsive visual system.
- Added persistent dark and light themes.
- Added 7, 14, and 30-day same-origin usage analytics.
- Added total-range usage and top-node summaries.
- Added live account refresh through `/{token}/info`.
- Expanded the client center to nine maintained clients across five operating systems.
- Added four-step Persian instructions and official download links for every client.
- Added supported one-click import schemes and a Clash Meta format route.
- Added direct configuration count, copy, copy-all, and individual QR tools.
- Expanded network testing to download, upload, ping, and jitter.
- Added mobile navigation, RTL keyboard tab behavior, accessible landmarks, and reduced-motion handling.
- Expanded account coverage to active, limited, expired, disabled, unlimited, and on-hold fixtures.
- Expanded automated QA to 16 scenarios plus HTTP smoke endpoints.
- Updated the installer and documentation for version 2.0.0.

## 1.2.0

- Previous stable Homa Ghost release with a seven-day chart, QR import, OS recommendations, and network testing.
