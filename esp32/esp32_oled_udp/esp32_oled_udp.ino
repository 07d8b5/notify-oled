/**
 * @file esp32_oled_udp.ino
 * @brief Main entry point.
 *
 * System summary:
 * - CPU clock fixed to 80 MHz.
 * - Boot-time 2.4GHz scan selects a channel (prefers 1/6/11).
 * - Starts a hidden SoftAP.
 * - Listens for UDP payloads and displays two 6-character lines on SSD1306.
 * - OLED failure does not stop operation; device continues headless with serial logs.
 * - No automatic recovery actions at runtime; only warning/diagnostic output.
 */

#include "config.h"
#include "display_oled.h"
#include "payload.h"
#include "wifi_ap.h"
#include "udp_rx.h"
#include "telemetry.h"
#include "leds.h"

#include <Arduino.h>
#include <Wire.h>
#include <WiFi.h>
#include <WiFiUdp.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <esp32-hal-cpu.h>

static Adafruit_SSD1306 g_display(OLED_W, OLED_H, &Wire, -1);
static WiFiUDP g_udp;

static bool g_oled_ok = false;
static int  g_ap_channel = 1;

static char g_line1[7] = "------";
static char g_line2[7] = "------";

static uint32_t g_packets = 0;
static uint32_t g_last_pkt_ms = 0;
static uint32_t g_last_status_ms = 0;
static uint32_t g_last_warn_ms = 0;
static bool     g_redraw_needed = true;

static void fatal_loop(const char* msg1, const char* msg2) {
  DisplayOLED::draw2(g_display, g_oled_ok, msg1, msg2);
  while (true) {
    Serial.printf("[FATAL] %s %s\n", msg1, msg2);
    delay(2000);
  }
}

void setup() {
  // Requirement: lock CPU to 80 MHz.
  setCpuFrequencyMhz(80);

  // Start serial after setting CPU frequency to keep UART stable.
  Serial.begin(115200);
  delay(200);
  Serial.printf("[BOOT] CPU=%dMHz\n", getCpuFrequencyMhz());

  // Optional GPIO-controlled status LED (disabled by default; see config.h).
  Leds::init();
  Leds::set_power(true);

  // I2C bus init.
  Wire.begin(OLED_SDA_PIN, OLED_SCL_PIN, I2C_HZ);

  // OLED init (headless allowed).
  g_oled_ok = DisplayOLED::init(g_display, /*tries=*/3);
  DisplayOLED::draw2(g_display, g_oled_ok, "BOOT", "----");

  // Boot-time scan -> choose AP channel.
  g_ap_channel = WifiAP::select_channel_on_boot();

  // Start AP.
  if (!WifiAP::start_softap(g_ap_channel)) {
    fatal_loop("APERR", "----");
  }

  // Bind UDP.
  if (!UdpRx::begin(g_udp, UDP_PORT, /*tries=*/3)) {
    fatal_loop("UDPERR", "----");
  }

  // Known start state.
  payload_set_line(g_line1, "READY", 5);
  payload_set_line(g_line2, "UDP777", 6);
  g_redraw_needed = true;
  DisplayOLED::draw2(g_display, g_oled_ok, g_line1, g_line2);

  g_packets = 0;
  g_last_pkt_ms = millis();
  g_last_status_ms = millis();
  g_last_warn_ms = 0;

  Serial.printf("[READY] AP_IP=%s UDP_PORT=%u CH=%d hidden=%d\n",
                WiFi.softAPIP().toString().c_str(),
                UDP_PORT,
                g_ap_channel,
                AP_HIDDEN);
}

void loop() {
  const uint32_t now = millis();

  Telemetry::maybe_print_status(now, g_packets, g_last_pkt_ms, g_ap_channel, g_line1, g_line2, &g_last_status_ms);
  Telemetry::maybe_warn_no_packets(now, g_last_pkt_ms, g_ap_channel, &g_last_warn_ms);

  // Redraw only when content changes.
  if (g_redraw_needed) {
    DisplayOLED::draw2(g_display, g_oled_ok, g_line1, g_line2);
    g_redraw_needed = false;
  }

  // Receive one UDP packet (if available).
  char buf[128];
  int len = 0;

  if (!UdpRx::recv_one(g_udp, buf, (int)sizeof(buf), &len)) {
    delay(5);
    return;
  }

  // Parse + hard-truncate into 6-char lines.
  char old1[7], old2[7];
  memcpy(old1, g_line1, 7);
  memcpy(old2, g_line2, 7);

  payload_parse(g_line1, g_line2, buf, len);

  if (memcmp(old1, g_line1, 7) != 0 || memcmp(old2, g_line2, 7) != 0) {
    g_redraw_needed = true;
  }

  g_packets++;
  g_last_pkt_ms = now;
  g_last_warn_ms = 0;

  // Log interpreted payload.
  Serial.printf("[DISP] '%s' / '%s'\n", g_line1, g_line2);
}
