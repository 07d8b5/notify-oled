#pragma once
/**
 * @file payload.h
 * @brief Payload parsing and line formatting.
 *
 * Contract:
 * - The display shows exactly two lines.
 * - Each line is exactly 6 characters (padded with spaces).
 * - Input is split on the first separator in {'\n', '|', ','}.
 * - If no separator exists, line2 becomes blank.
 */

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Format a line into a fixed 6-char buffer (plus NUL).
 * @param dst Destination buffer, must be at least 7 bytes.
 * @param src Source string (not necessarily NUL-terminated within n).
 * @param n   Number of bytes available in src.
 */
void payload_set_line(char dst[7], const char* src, int n);

/**
 * @brief Parse incoming payload into two 6-char padded lines.
 * @param line1 Output line1 buffer (7 bytes).
 * @param line2 Output line2 buffer (7 bytes).
 * @param buf   Input buffer.
 * @param len   Length of input buffer in bytes.
 */
void payload_parse(char line1[7], char line2[7], const char* buf, int len);

#ifdef __cplusplus
}
#endif
