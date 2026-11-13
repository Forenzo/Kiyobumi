#ifndef OPENNOTEBOOK_ONESTORE_H
#define OPENNOTEBOOK_ONESTORE_H
#include <stddef.h>
#include <stdint.h>
/* Reads exactly the supplied header; actual_length is the complete file size.
 * 0 = recognized modern section header (NOT content import); 1 = truncated;
 * 2 = wrong file type; 3 = unsupported format/version; 4 = inconsistent bounds;
 * 5 = invalid pointer. bytes must reference at least length readable bytes. */
int32_t onestore_probe(const uint8_t *bytes, size_t length, uint64_t actual_length);
#endif
