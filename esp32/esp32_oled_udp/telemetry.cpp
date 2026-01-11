/**
 * @file telemetry.cpp
 * @brief Serial telemetry implementation.
 */

#include "telemetry.h"
#include "config.h"

#include <Arduino.h>
#include <WiFi.h>

namespace Telemetry {

void maybe_print_status(uint32_t now_ms,
                        uint32_t packets,
                        uint32_t last_pkt_ms,
                        int ap_channel,
                        const char line1[7],
                        const char line2[7],
                        uint32_t* last_status_ms) {
  if (now_ms - *last_status_ms < STATUS_EVERY_MS) return;
  *last_status_ms = now_ms;

  Serial.printf("[STAT] up=%lus pkts=%lu last=%lums stations=%d ch=%d l1='%s' l2='%s'\n",
                (unsigned long)(now_ms / 1000),
                (unsigned long)packets,
                (unsigned long)(now_ms - last_pkt_ms),
                (int)WiFi.softAPgetStationNum(),
                ap_channel,
                line1, line2);
}

void maybe_warn_no_packets(uint32_t now_ms,
                           uint32_t last_pkt_ms,
                           int ap_channel,
                           uint32_t* last_warn_ms) {
  const uint32_t quiet_ms = now_ms - last_pkt_ms;
  if (quiet_ms < NO_PACKET_WARN_MS) return;

  if (*last_warn_ms != 0 && (now_ms - *last_warn_ms) < NO_PACKET_WARN_EVERY_MS) return;
  *last_warn_ms = now_ms;

  Serial.printf("[WARN] No UDP packets for %lums (stations=%d AP_IP=%s ch=%d)\n",
                (unsigned long)quiet_ms,
                (int)WiFi.softAPgetStationNum(),
                WiFi.softAPIP().toString().c_str(),
                ap_channel);
}

} // namespace Telemetry
