/**
 * @file display_oled.cpp
 * @brief OLED drawing and initialization.
 */

#include "display_oled.h"
#include "config.h"

#include <Arduino.h>
#include <Adafruit_SSD1306.h>

namespace DisplayOLED {

bool init(Adafruit_SSD1306& display, int tries) {
  for (int t = 1; t <= tries; t++) {
    Serial.printf("[OLED] begin try %d/%d addr=0x%02X\n", t, tries, OLED_I2C_ADDR);
    if (display.begin(SSD1306_SWITCHCAPVCC, OLED_I2C_ADDR)) {
      Serial.println("[OLED] OK");
      return true;
    }
    Serial.println("[OLED] FAILED (addr/wiring/power). Retrying...");
    delay(200);
  }
  Serial.println("[OLED] Giving up; running headless (serial-only).");
  return false;
}

void draw2(Adafruit_SSD1306& display, bool oled_ok, const char* a, const char* b) {
  if (!oled_ok) return;

  const int textSize = 2;
  const int lineH = 8 * textSize;
  const int gap   = 2;

  const int x  = OLED_XOFF;
  const int y1 = OLED_YOFF + 12; // calibrated baseline
  const int y2 = y1 + lineH + gap;

  display.clearDisplay();
  display.setTextSize(textSize);
  display.setTextColor(SSD1306_WHITE);

  display.setCursor(x, y1);
  display.print(a);

  display.setCursor(x, y2);
  display.print(b);

  display.display();
}

} // namespace DisplayOLED
