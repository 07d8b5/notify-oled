#pragma once
/**
 * @file udp_rx.h
 * @brief UDP receiver for display payloads.
 *
 * Responsibilities:
 * - Bind UDP port.
 * - Receive packets into a bounded buffer.
 * - Trim trailing whitespace (but preserve leading spaces).
 *
 * Notes:
 * - On Arduino-ESP32 core 3.x, WiFiUDP is a typedef (not a class),
 *   so we include <WiFiUdp.h> here instead of forward-declaring.
 */

#include <stdint.h>
#include <WiFiUdp.h>  // must be included (WiFiUDP is a typedef in core 3.x)

namespace UdpRx {

/**
 * @brief Bind UDP port with retries.
 * @param udp WiFiUDP instance.
 * @param port UDP port to bind.
 * @param tries Retry count.
 * @return true on success, false on failure.
 */
bool begin(WiFiUDP& udp, uint16_t port, int tries);

/**
 * @brief Attempt to receive one packet.
 * @param udp WiFiUDP instance.
 * @param buf Output buffer.
 * @param cap Capacity of buffer in bytes.
 * @param out_len Output length (bytes) after trimming; valid if return true.
 * @return true if a packet was received and placed into buf, false otherwise.
 */
bool recv_one(WiFiUDP& udp, char* buf, int cap, int* out_len);

} // namespace UdpRx
