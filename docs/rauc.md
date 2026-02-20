# RAUC Integration Notes

## System Configuration
- system.conf lives at `/etc/rauc/system.conf`.
- The compatible string is `ivi-hu-rpi4`.

## Bundle Signing
Use `tools/rauc-generate-keys.sh` to generate a private key and certificate.
Copy `rauc.cert.pem` to `/etc/rauc/ca.cert.pem` on the device, and set the Yocto `RAUC_KEY_FILE`/`RAUC_CERT_FILE` for bundle signing.

## Bootloader Strategy
The Raspberry Pi firmware does not provide native A/B boot selection. For a dev/demo flow:
- Keep `/boot` shared.
- RAUC installs into inactive rootfs.
- Use a custom boot selection mechanism (e.g., `cmdline.txt` swap or a U-Boot-based flow).

Production guidance:
- Use U-Boot with RAUC integration (bootcount + environment) or a dedicated bootloader that can select slots.
- Ensure the bootloader supports rollback based on RAUC slot state.
