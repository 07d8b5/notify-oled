# ESP32 firmware

The Arduino sketch lives in `esp32_oled_udp/`.

## Build requirements

- ESP32 board support (Espressif)
- Libraries:
  - Adafruit_GFX
  - Adafruit_SSD1306

## Configuration

Edit `esp32_oled_udp/config.h`:
- SoftAP SSID/PSK
- UDP port
- OLED I2C pins/address
- LED control (disabled by default)

### Keeping Wi‑Fi credentials out of git

You can create `esp32_oled_udp/config_local.h` (ignored by git) and define
override macros there:

- `NOTIFY_AP_SSID`
- `NOTIFY_AP_PASS`
- `NOTIFY_UDP_PORT`
- `NOTIFY_SCAN_LOG_SSIDS` (1 to print nearby SSIDs to Serial during boot scan)

## Serial diagnostics

Use 115200 baud.
