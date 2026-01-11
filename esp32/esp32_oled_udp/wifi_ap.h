#pragma once
/**
 * @file wifi_ap.h
 * @brief SoftAP setup and boot-time channel selection.
 *
 * Channel selection:
 * - Perform a synchronous scan at boot.
 * - Score channels using RSSI + overlap penalties.
 * - Prefer 1/6/11 if possible.
 * - Start SoftAP on the chosen channel.
 *
 * Note: Scan is performed before AP start, so it does not disrupt clients.
 */

#include <stdbool.h>

namespace WifiAP {

/**
 * @brief Select a "least congested" 2.4GHz channel using a boot-time scan.
 * @return Selected channel (CH_MIN..CH_MAX), falls back to 1 on failure.
 */
int select_channel_on_boot();

/**
 * @brief Start SoftAP with configured SSID/password on the given channel.
 * @param channel Channel number to use.
 * @return true if SoftAP started successfully, false otherwise.
 */
bool start_softap(int channel);

} // namespace WifiAP
