/**
 * @file udp_rx.cpp
 * @brief UDP receiver implementation.
 */

#include "udp_rx.h"

#include <Arduino.h>

namespace UdpRx {

bool begin(WiFiUDP& udp, uint16_t port, int tries) {
  for (int t = 1; t <= tries; t++) {
    Serial.printf("[UDP] begin try %d/%d port=%u\n", t, tries, port);
    if (udp.begin(port)) {
      Serial.println("[UDP] OK");
      return true;
    }
    Serial.println("[UDP] FAILED. Retrying...");
    delay(200);
  }
  return false;
}

bool recv_one(WiFiUDP& udp, char* buf, int cap, int* out_len) {
  const int packetSize = udp.parsePacket();
  if (packetSize <= 0) return false;

  const int maxRead = cap - 1;
  int n = udp.read(buf, maxRead);
  if (n <= 0) return false;

  buf[n] = '\0';

  // Trim trailing whitespace only (preserve leading spaces).
  while (n > 0) {
    const char c = buf[n - 1];
    if (c == '\r' || c == '\n' || c == ' ' || c == '\t') {
      buf[n - 1] = '\0';
      n--;
      continue;
    }
    break;
  }

  *out_len = n;

  Serial.printf("[UDP] pkt=%dB read=%dB from %s:%u\n",
                packetSize,
                n,
                udp.remoteIP().toString().c_str(),
                udp.remotePort());
  return true;
}

} // namespace UdpRx
