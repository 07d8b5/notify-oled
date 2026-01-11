#pragma once
/**
 * @file telemetry.h
 * @brief Serial telemetry helpers.
 *
 * Provides periodic status and idle warnings without taking any recovery action.
 */

#include <stdint.h>

namespace Telemetry {

/**
 * @brief Update periodic status output.
 * @param now_ms Current time from millis().
 * @param packets Total packets received so far.
 * @param last_pkt_ms Time of last packet reception (millis()).
 * @param ap_channel Current AP channel.
 * @param line1 Display line 1.
 * @param line2 Display line 2.
 * @param last_status_ms In/out: last status print time.
 */
void maybe_print_status(uint32_t now_ms,
                        uint32_t packets,
                        uint32_t last_pkt_ms,
                        int ap_channel,
                        const char line1[7],
                        const char line2[7],
                        uint32_t* last_status_ms);

/**
 * @brief Warn if no packets have arrived recently (no restart, no recovery).
 * @param now_ms Current time from millis().
 * @param last_pkt_ms Time of last packet reception (millis()).
 * @param ap_channel Current AP channel.
 * @param last_warn_ms In/out: last warning print time.
 */
void maybe_warn_no_packets(uint32_t now_ms,
                           uint32_t last_pkt_ms,
                           int ap_channel,
                           uint32_t* last_warn_ms);

} // namespace Telemetry
