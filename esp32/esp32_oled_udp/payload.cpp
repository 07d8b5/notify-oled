/**
 * @file payload.cpp
 * @brief Implementation of payload parsing and line formatting.
 */

#include "payload.h"

void payload_set_line(char dst[7], const char* src, int n) {
  int i = 0;
  for (; i < 6 && i < n && src[i] != '\0'; i++) dst[i] = src[i];
  for (; i < 6; i++) dst[i] = ' ';
  dst[6] = '\0';
}

void payload_parse(char line1[7], char line2[7], const char* buf, int len) {
  // Accept separators: '\n' or '|' or ','.
  int sep = -1;
  for (int i = 0; i < len; i++) {
    const char c = buf[i];
    if (c == '\n' || c == '|' || c == ',') { sep = i; break; }
  }

  if (sep < 0) {
    payload_set_line(line1, buf, len);
    payload_set_line(line2, "", 0);
    return;
  }

  payload_set_line(line1, buf, sep);

  int start2 = sep + 1;
  // Preserve leading spaces on line 2; skip only newline/CR.
  while (start2 < len && (buf[start2] == '\r' || buf[start2] == '\n')) start2++;

  payload_set_line(line2, buf + start2, len - start2);
}
