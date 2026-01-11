# Security policy

This project is designed for local networks and small deployments.

## Reporting

If you discover a security issue, do not open a public issue with sensitive details.
Instead, contact the maintainer privately.

## Sensitive data

Do not commit:
- Wi‑Fi credentials (SSIDs, PSKs)
- API tokens, passwords
- SSH keys or private certificates
- Host inventories, internal addressing plans, or other environment‑specific details

Recommended practice:
- Keep real credentials in local, ignored files (e.g., `config/local.*`), and copy from templates.
- Keep runtime data out of version control (`out/`, `logs/`).

## Network exposure

The sender/receiver communication uses UDP and is intended for a trusted LAN.
Do not expose the ESP32 receiver or the UDP port to the public Internet.
