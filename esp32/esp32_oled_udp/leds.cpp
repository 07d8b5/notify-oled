/**
 * @file leds.cpp
 * @brief Optional firmware-controlled LEDs.
 */

#include "config.h"
#include "leds.h"

#include <Arduino.h>

namespace {

inline bool power_led_available() {
  return LEDS_ENABLED && POWER_LED_PIN >= 0;
}

inline void write_power_led(bool on) {
  if (!power_led_available()) return;
  const bool level = POWER_LED_ACTIVE_LOW ? !on : on;
  digitalWrite(POWER_LED_PIN, level ? HIGH : LOW);
}

} // namespace

namespace Leds {

void init() {
  if (!power_led_available()) return;
  pinMode(POWER_LED_PIN, OUTPUT);
  // Default state: OFF (leds are disabled by default anyway, but be explicit).
  write_power_led(false);
}

void set_power(bool on) {
  write_power_led(on);
}

} // namespace Leds
