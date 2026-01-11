#pragma once
/**
 * @file leds.h
 * @brief Optional firmware-controlled LEDs (compile-time configurable).
 */

namespace Leds {

/** Initialize configured LED pins (no-op if disabled). */
void init();

/** Set the firmware-controlled "power/status" LED. */
void set_power(bool on);

} // namespace Leds
