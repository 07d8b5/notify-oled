#pragma once
/**
 * @file config.h
 * @brief Project configuration constants.
 *
 * This file contains all tunable parameters for the device:
 * OLED wiring, SoftAP settings, UDP port, logging intervals, and
 * channel selection policy.
 */

#include <stdint.h>

// Optional local overrides (not committed). This lets you keep real Wi‑Fi
// credentials out of git by defining NOTIFY_* macros in config_local.h.
#ifdef __has_include
#  if __has_include("config_local.h")
#    include "config_local.h"
#  endif
#endif

// -------------------- Overrideable defaults (macros) --------------------

#ifndef NOTIFY_AP_SSID
#  define NOTIFY_AP_SSID "notify-oled"
#endif

#ifndef NOTIFY_AP_PASS
#  define NOTIFY_AP_PASS "change-me"
#endif

#ifndef NOTIFY_UDP_PORT
#  define NOTIFY_UDP_PORT 7777
#endif

#ifndef NOTIFY_SCAN_LOG_SSIDS
#  define NOTIFY_SCAN_LOG_SSIDS 0
#endif

// -------------------- OLED --------------------

/** OLED width in pixels. */
static constexpr int OLED_W = 128;
/** OLED height in pixels. */
static constexpr int OLED_H = 64;

/** OLED I2C SDA pin (ESP32-C3). */
static constexpr int OLED_SDA_PIN = 5;
/** OLED I2C SCL pin (ESP32-C3). */
static constexpr int OLED_SCL_PIN = 6;
/** OLED I2C address (commonly 0x3C). */
static constexpr uint8_t OLED_I2C_ADDR = 0x3C;

/** OLED text baseline offsets tuned for this hardware layout. */
static constexpr int OLED_XOFF = 28;
static constexpr int OLED_YOFF = 14;

/** I2C bus speed in Hz. Use 100000 if wiring is long/noisy. */
static constexpr uint32_t I2C_HZ = 400000;

// -------------------- SoftAP --------------------

/** SoftAP SSID. */
static constexpr const char* AP_SSID = NOTIFY_AP_SSID;
/** SoftAP password (WPA2-PSK). */
static constexpr const char* AP_PASS = NOTIFY_AP_PASS;

/** SoftAP: hide SSID (1 = hidden, 0 = broadcast). */
static constexpr int AP_HIDDEN = 0;
/** SoftAP: maximum station connections. */
static constexpr int AP_MAXCONN = 4;

// -------------------- UDP --------------------

/** UDP listen port for inbound display payloads. */
static constexpr uint16_t UDP_PORT = (uint16_t)NOTIFY_UDP_PORT;

/**
 * @brief Whether to print SSIDs during the boot-time Wi‑Fi scan.
 *
 * Keeping this disabled avoids leaking nearby network names into serial logs.
 */
static constexpr bool SCAN_LOG_SSIDS = (NOTIFY_SCAN_LOG_SSIDS != 0);

// -------------------- Runtime telemetry --------------------

/** Periodic status line interval (ms). */
static constexpr uint32_t STATUS_EVERY_MS = 10'000;
/** Warn if no UDP packets received for this long (ms). */
static constexpr uint32_t NO_PACKET_WARN_MS = 30'000;
/** Do not repeat the warning faster than this (ms). */
static constexpr uint32_t NO_PACKET_WARN_EVERY_MS = 30'000;

// -------------------- Boot-time channel selection --------------------

/**
 * @brief Minimum channel to consider for 2.4GHz.
 * For the US, 1..11 is safe and avoids 12/13 client compatibility issues.
 */
static constexpr int CH_MIN = 1;
/** Maximum channel to consider for 2.4GHz (US-safe). */
static constexpr int CH_MAX = 11;

/** Preferred non-overlapping channels for 2.4GHz. */
static constexpr int PREFERRED_CH[3] = {1, 6, 11};
static constexpr int PREFERRED_CH_N = 3;

// -------------------- LEDs --------------------

/**
 * @brief Master kill-switch for ALL firmware-controlled LEDs.
 *
 * This only affects GPIO-driven "user/status" LEDs.
 * A hardwired power LED on your board (VCC -> LED -> resistor -> GND)
 * cannot be disabled in software.
 */
static constexpr bool LEDS_ENABLED = false;

/**
 * @brief GPIO pin for the "power/status" LED the firmware can control.
 *
 * Set to -1 to disable this LED even if LEDS_ENABLED is true.
 *
 * Common examples (board-dependent):
 * - ESP32-C3 SuperMini: often GPIO8
 * - ESP32 DevKit: often GPIO2
 */
static constexpr int POWER_LED_PIN = -1;

/**
 * @brief Whether the power LED is wired active-low.
 *
 * If the LED turns ON when the pin is LOW, set true.
 */
static constexpr bool POWER_LED_ACTIVE_LOW = false;
