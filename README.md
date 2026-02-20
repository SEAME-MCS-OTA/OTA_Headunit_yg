# IVI Head Unit on Raspberry Pi 4

This repository is a practical reference project for an in-vehicle infotainment (IVI) head unit.
It combines:

- Yocto-based Linux image build
- RAUC A/B OTA update flow
- Weston (Wayland compositor) for display
- Qt6/QML full-screen head unit UI
- FastAPI OTA backend service

The goal is to let you build, flash, boot, and operate a working demo system on Raspberry Pi 4.

## Table of Contents

1. [What You Get](#what-you-get)
2. [How the System Works](#how-the-system-works)
3. [Repository Layout](#repository-layout)
4. [Requirements](#requirements)
5. [Quick Start (Build to SD Boot)](#quick-start-build-to-sd-boot)
6. [Boot Sequence on Device](#boot-sequence-on-device)
7. [UI Pages and Features](#ui-pages-and-features)
8. [OTA Backend API](#ota-backend-api)
9. [RAUC Slots and Partitioning](#rauc-slots-and-partitioning)
10. [Log Collection and Where to Look](#log-collection-and-where-to-look)
11. [Update Strategy: Rebuild vs SD-only Patch](#update-strategy-rebuild-vs-sd-only-patch)
12. [Troubleshooting](#troubleshooting)
13. [Default Wi-Fi Profile](#default-wi-fi-profile)
14. [Known Limits](#known-limits)

## What You Get

After a successful build and flash, the device should:

- Boot into Linux on Raspberry Pi 4
- Start Weston automatically
- Start `headunit-ui` (Qt app) in full-screen over Wayland
- Run OTA backend on port `8080`
- Save UI/Weston diagnostics under `/data/log/ui`
- Open map and YouTube from Qt WebEngine pages
- Show current time in OTA page `Content` section

## How the System Works

```text
                     +--------------------------------------+
                     |           OTA Backend (FastAPI)      |
                     |   /ota/start, /ota/status, /health   |
                     +-------------------+------------------+
                                         |
                                         | runs RAUC commands
                                         v
+-------------------+      Wayland      +-------------------+
|   Qt6/QML UI      | <---------------> |      Weston       |
|   headunit-ui     |                    |   DRM/KMS output  |
+---------+---------+                    +---------+---------+
          |                                          |
          | reads status / starts OTA                | renders to HDMI
          +------------------------------+-----------+
                                         |
                                         v
                               +-------------------+
                               |   RAUC A/B slots  |
                               | rootfsA / rootfsB |
                               +-------------------+
```

## Repository Layout

```text
OTA_HEADUNIT/
├── Dockerfile
├── docker-compose.yml
├── tools/
│   ├── yocto-init.sh
│   ├── build-image.sh
│   ├── build-rauc-bundle.sh
│   └── rauc-generate-keys.sh
├── yocto/
│   ├── conf/
│   ├── meta-myproduct/
│   └── sources/
├── ui/qt-headunit/
│   ├── src/main.cpp
│   ├── qml/
│   │   ├── Main.qml
│   │   ├── pages/
│   │   │   ├── HomePage.qml
│   │   │   ├── NavPage.qml
│   │   │   ├── MediaPage.qml
│   │   │   └── OtaPage.qml
│   │   ├── components/
│   │   └── services/OtaApi.js
│   ├── systemd/
│   │   ├── headunit.service
│   │   ├── ui-log-collector.service
│   │   └── ui-log-collector.timer
│   └── weston/weston.ini
├── services/ota-backend/
│   ├── app/
│   │   ├── main.py
│   │   ├── models.py
│   │   └── ota_logic.py
│   └── systemd/ota-backend.service
├── docs/
│   ├── rauc.md
│   └── partitioning.md
├── systemd/
├── _build/    # Yocto build output
├── _cache/    # downloads/sstate
└── out/       # exported artifacts
```

## Requirements

Host machine:

- Linux (Ubuntu recommended)
- Docker 20.10+
- Docker Compose v2 (`docker compose`)
- 16 GB RAM or more
- 100 GB free disk or more

Hardware:

- Raspberry Pi 4
- SD card (size depends on image and data usage)
- HDMI display

## Quick Start (Build to SD Boot)

### 1) Build the container image

```bash
docker compose build
```

### 2) Initialize Yocto sources and layers

```bash
docker compose run --rm yocto bash -lc './tools/yocto-init.sh'
```

### 3) Build target image

```bash
docker compose run --rm yocto bash -lc './tools/build-image.sh'
```

### 4) Optional: build RAUC bundle

```bash
docker compose run --rm yocto bash -lc './tools/build-rauc-bundle.sh'
```

### 5) Flash SD card

```bash
lsblk
zcat out/my-hu-image-raspberrypi4-64.rootfs.wic.gz | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
sync
```

Replace `/dev/sdX` with your actual SD card device path.

Tip:

- `tools/build-image.sh` refreshes `out/my-hu-image-raspberrypi4-64.rootfs.wic.gz`
  to point at the latest timestamped image.
- If you want an exact artifact, flash `out/my-hu-image-raspberrypi4-64.rootfs-<timestamp>.wic.gz` directly.

### 6) Boot the device and verify services

On the device console:

```bash
systemctl status seatd weston headunit ota-backend --no-pager
```

Expected:

- `weston` is active
- `headunit` is active
- `ota-backend` is active

## Boot Sequence on Device

The intended boot flow is:

1. `seatd.service` starts (seat management for compositor access).
2. `weston.service` starts (Wayland compositor).
3. `headunit.service` waits for `/run/weston/wayland-*`.
4. `headunit-ui` starts with `QT_QPA_PLATFORM=wayland`.
5. `ui-log-collector.timer` periodically stores diagnostic logs in `/data/log/ui`.

Important implementation detail:

- `ui/qt-headunit/systemd/headunit.service` uses `ExecStartPre` to wait for Wayland socket.
- This avoids race conditions where Qt starts before Weston socket exists.

## UI Pages and Features

Main entry:

- `ui/qt-headunit/qml/Main.qml`

Pages:

- `HomePage.qml`: launcher and top-level status view.
- `NavPage.qml`: map view using `WebEngineView` + local iframe wrapper (`NavMapView.html`).
- `MediaPage.qml`: media page with real YouTube web view (`MediaYoutubeWebView.qml`).
- `OtaPage.qml`: OTA page with status, flow display, auto polling, and `Content` time display.

Service module:

- `ui/qt-headunit/qml/services/OtaApi.js`
- Centralizes OTA HTTP calls used by QML pages.

Note about QML updates:

- QML is bundled into the `headunit-ui` binary via `qml.qrc`.
- Editing files on mounted SD rootfs does not always update runtime behavior unless you rebuild and redeploy `headunit-ui`.
- `NavMapView.html` is also bundled via `qml.qrc`, so map behavior changes require UI rebuild too.

## OTA Backend API

Service implementation:

- `services/ota-backend/app/main.py`

Default endpoint:

- `http://<device-ip>:8080`

APIs:

- `GET /health`: service health check
- `GET /ota/status`: current OTA + slot status
- `POST /ota/start`: start OTA with bundle URL
- `POST /ota/reboot`: trigger system reboot

Example OTA start call:

```bash
curl -X POST http://<device-ip>:8080/ota/start \
  -H 'Content-Type: application/json' \
  -d '{"ota_id":"ota-20260130-319f58","url":"https://server/bundle.raucb","target_version":"1.2.4"}'
```

## RAUC Slots and Partitioning

Reference docs:

- `docs/rauc.md`
- `docs/partitioning.md`
- `yocto/meta-myproduct/recipes-core/images/my-hu-image.wks`

Current layout concept:

- `p1`: `/boot` (shared)
- `p2`: `rootfsA`
- `p3`: `rootfsB`
- `p4`: `/data`

RAUC behavior:

- Installs update to inactive rootfs slot.
- Shared `/boot` strategy is used for this project/demo flow.
- Production system should use explicit bootloader slot control and rollback policy.

## Log Collection and Where to Look

Primary runtime logs on target:

- `/data/log/ui/weston.log`
- `/data/log/ui/weston-err.log`
- `/data/log/ui/weston-journal.log`
- `/data/log/ui/headunit-journal.log`
- `/data/log/ui/boot-*.log`

Relevant service definitions:

- `yocto/meta-myproduct/recipes-core/systemd/files/weston.service`
- `ui/qt-headunit/systemd/headunit.service`
- `ui/qt-headunit/systemd/ui-log-collector.service`
- `ui/qt-headunit/systemd/ui-log-collector.timer`

Useful commands on target:

```bash
journalctl -u weston.service -b --no-pager
journalctl -u headunit.service -b --no-pager
cat /data/log/ui/weston-err.log
```

## Update Strategy: Rebuild vs SD-only Patch

Use rebuild when:

- You changed QML/C++ UI code
- You changed Yocto recipes or package composition
- You need a reproducible image artifact

You can patch SD card directly (for quick validation only) when:

- You only changed runtime config files (for example `weston.ini`, service unit files, simple scripts)
- You understand these changes are not yet baked into Yocto image

Recommended workflow:

1. Quick test by patching mounted SD rootfs.
2. If behavior is correct, apply equivalent change to repository files.
3. Rebuild image so the fix is permanent and reproducible.

## Troubleshooting

### Weston shows, but Qt UI is missing

Check:

```bash
journalctl -u headunit.service -b --no-pager
ls -la /run/weston
```

Verify:

- Wayland socket exists
- `headunit.service` has correct `XDG_RUNTIME_DIR` and `QT_QPA_PLATFORM`

### Only part of the screen is used by Qt

Check output mode in:

- `ui/qt-headunit/weston/weston.ini`
- `/data/log/ui/weston.log`

If needed, set each HDMI output mode explicitly and redeploy.

### Map or YouTube region shows only a center rectangle

Most common causes:

- Network unavailable
- Incorrect system time (TLS/HTTPS validation fails)
- GPU/video backend limitations for embedded web/video path

Validate:

```bash
date
ping -c 3 8.8.8.8
cat /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
```

For map page in current implementation:

- `NavPage.qml` loads `qrc:/pages/NavMapView.html`
- `NavMapView.html` embeds Google Maps in an `<iframe>`
- If map fails, check internet first, then check WebEngine errors in `headunit` journal

### OTA time appears with timezone offset

Current OTA page behavior:

- `Current Time` prefers `context.time.local`, then `ts`
- ISO timestamp strings are rendered as wall-clock text (`YYYY-MM-DD HH:MM:SS`)
  to avoid device timezone conversion drift (for example 1-hour offset)

If time is still wrong:

- Verify backend payload (`context.time.local`, `ts`)
- Verify target timezone files:
  - `/etc/localtime`
  - `/etc/timezone`
- Verify service runtime env in `headunit.service`

### Service enable/restart commands fail on host machine

If you run commands like `systemctl restart weston` on your Ubuntu host, they will fail because those services exist on the target image, not on host OS.

Run service commands:

- On the Raspberry Pi target console, or
- In mounted rootfs by editing files before boot (not by host `systemctl`)

## Default Wi-Fi Profile

Default Wi-Fi profile is baked into Yocto through:

- `yocto/meta-myproduct/recipes-connectivity/wpa-supplicant/files/wpa_supplicant.conf`

Current default network:

- SSID: `SEA:ME WiFi Access`
- Password: `1fy0u534m3`

Installed on target as:

- `/etc/wpa_supplicant/wpa_supplicant.conf`
- `/etc/wpa_supplicant/wpa_supplicant-wlan0.conf`

## Known Limits

- Raspberry Pi firmware does not provide built-in RAUC A/B boot decision logic.

