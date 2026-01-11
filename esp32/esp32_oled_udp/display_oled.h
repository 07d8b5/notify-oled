#pragma once
/**
 * @file display_oled.h
 * @brief OLED display wrapper.
 *
 * Behavior:
 * - Initializes SSD1306 over I2C with retries.
 * - If init fails, the system runs in "headless" mode (serial only).
 * - Drawing functions are no-ops when headless.
 */

#include <stdbool.h>

class Adafruit_SSD1306;

namespace DisplayOLED {

/**
 * @brief Initialize the OLED.
 * @param display Reference to a constructed Adafruit_SSD1306 object.
 * @param tries Number of retry attempts.
 * @return true if the OLED was initialized successfully, false if headless.
 */
bool init(Adafruit_SSD1306& display, int tries);

/**
 * @brief Draw exactly two lines (text size 2) to the OLED.
 * @param display Reference to a valid Adafruit_SSD1306 object.
 * @param oled_ok If false, this function does nothing.
 * @param a First line (expected <= 6 chars, may include spaces).
 * @param b Second line (expected <= 6 chars, may include spaces).
 */
void draw2(Adafruit_SSD1306& display, bool oled_ok, const char* a, const char* b);

} // namespace DisplayOLED
