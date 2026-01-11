/**
 * @file wifi_ap.cpp
 * @brief SoftAP setup + boot-time channel selection implementation.
 */

#include "wifi_ap.h"
#include "config.h"

#include <Arduino.h>
#include <WiFi.h>

namespace {

int rssi_weight(int rssi) {
  // rssi is negative dBm; -30 is very strong, -90 is weak.
  if (rssi >= -50) return 6;
  if (rssi >= -60) return 4;
  if (rssi >= -70) return 2;
  if (rssi >= -80) return 1;
  return 0;
}

void add_overlap_penalty(int score[12], int ch, int w) {
  // Simple overlap model: center channel gets 3w, +/-1 gets 2w, +/-2 gets 1w.
  if (ch < CH_MIN || ch > CH_MAX) return;

  score[ch] += 3 * w;
  if (ch - 1 >= CH_MIN) score[ch - 1] += 2 * w;
  if (ch + 1 <= CH_MAX) score[ch + 1] += 2 * w;
  if (ch - 2 >= CH_MIN) score[ch - 2] += 1 * w;
  if (ch + 2 <= CH_MAX) score[ch + 2] += 1 * w;
}

int choose_best_channel_from_scan(int16_t n) {
  int score[12]; // 0 unused; 1..11 valid
  for (int i = 0; i < 12; i++) score[i] = 0;

  for (int i = 0; i < n; i++) {
    const int ch = WiFi.channel(i);
    const int r  = WiFi.RSSI(i);
    if (ch < CH_MIN || ch > CH_MAX) continue;

    const int w = rssi_weight(r);
    if (w == 0) continue;

    add_overlap_penalty(score, ch, w);
  }

  // Prefer 1/6/11 first.
  int best = PREFERRED_CH[0];
  int bestScore = score[best];

  for (int k = 1; k < PREFERRED_CH_N; k++) {
    const int ch = PREFERRED_CH[k];
    if (score[ch] < bestScore) { bestScore = score[ch]; best = ch; }
  }
  return best;
}

// Compatibility wrapper for scanNetworks() overload differences.
int16_t scanNetworksSync(bool show_hidden) {
#if defined(ESP_ARDUINO_VERSION_MAJOR) && (ESP_ARDUINO_VERSION_MAJOR >= 2)
  return WiFi.scanNetworks(/*async=*/false, /*show_hidden=*/show_hidden);
#else
  (void)show_hidden;
  return WiFi.scanNetworks();
#endif
}

} // namespace

namespace WifiAP {

int select_channel_on_boot() {
  // Enable STA capability only for scanning; we do not join any network.
  WiFi.mode(WIFI_AP_STA);

#if defined(ESP_ARDUINO_VERSION_MAJOR) && (ESP_ARDUINO_VERSION_MAJOR >= 2)
  WiFi.disconnect(true, true);
#else
  WiFi.disconnect();
#endif
  delay(100);

  Serial.println("[SCAN] scanning 2.4GHz for best channel (boot) ...");

  const int16_t n = scanNetworksSync(true);
  if (n < 0) {
    Serial.printf("[SCAN] scan failed (rc=%d). Fallback channel=1\n", (int)n);
    WiFi.scanDelete();
    return 1;
  }

  Serial.printf("[SCAN] found %d networks\n", (int)n);
  for (int i = 0; i < n && i < 8; i++) {
    if (SCAN_LOG_SSIDS) {
      Serial.printf("[SCAN] %2d: ch=%2d rssi=%4d ssid='%s'\n",
                    i, WiFi.channel(i), WiFi.RSSI(i), WiFi.SSID(i).c_str());
    } else {
      Serial.printf("[SCAN] %2d: ch=%2d rssi=%4d\n",
                    i, WiFi.channel(i), WiFi.RSSI(i));
    }
  }

  const int best = choose_best_channel_from_scan(n);
  Serial.printf("[SCAN] selected channel=%d\n", best);

  WiFi.scanDelete();
  return best;
}

bool start_softap(int channel) {
  // After scanning, switch to AP-only mode for steady operation.
  WiFi.mode(WIFI_AP);

  Serial.printf("[WIFI] starting SoftAP ssid='%s' ch=%d hidden=%d max=%d\n",
                AP_SSID, channel, AP_HIDDEN, AP_MAXCONN);

  if (!WiFi.softAP(AP_SSID, AP_PASS, channel, AP_HIDDEN, AP_MAXCONN)) {
    Serial.println("[WIFI] softAP() FAILED");
    return false;
  }

  Serial.printf("[WIFI] AP up. IP=%s stations=%d\n",
                WiFi.softAPIP().toString().c_str(),
                (int)WiFi.softAPgetStationNum());
  return true;
}

} // namespace WifiAP
