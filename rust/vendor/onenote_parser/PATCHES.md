# Kiyobumi 0.3.1 parser modifications (MPL-2.0)

This directory contains onenote_parser 2.0.0 from the crates.io distribution,
upstream commit fa4d7a044324af3bfe68727704a9789a08b36a3c.
Original authorship remains with the upstream contributors. Kiyobumi's
modifications to these covered files remain MPL-2.0.

Changes:
- src/onestore/desktop/objects/revision.rs accepts standalone
  ObjectInfoDependencyOverridesFND records at revision level, including after
  root references. The decoder still parses/validates the record bytes.
  Reference counts do not alter the read-only materialized object properties.
  This is expressly permitted by MS-ONESTORE 2.1.9.
- src/onenote/ink.rs reconstructs dimension-major first-order deltas before
  applying InkScalingX/Y. It rejects incomplete axes and accumulator overflow.
  Two synthetic unit tests exercise signed deltas, per-stroke reset and scaling.
- Cargo.toml removes unused benchmark/snapshot test dependencies (criterion,
  insta and yare). tempfile/bytes remain for the crate's existing unit tests.
  Original normalized manifest content is documented by Cargo.toml.orig.
  The full application's rust/Cargo.lock pins dependencies.

References (structure facts and documented behavior; no code copied):
https://learn.microsoft.com/en-us/openspecs/office_file_formats/ms-onestore/90101e91-2f7f-4753-9332-31bed5b5c49d
https://cable729.github.io/inkterop/docs/formats/onenote/
The latter project's empirical InkPath notes describe first-order deltas and
HIMETRIC/InkScaling mapping. The small reconstruction loop is original code.

Validation: all 67 parser unit tests pass in the workspace feature set,
including the two new ink cases.
The private Boilers and Combustion section now imports nine pages and 2,932
strokes; it previously stopped at a standalone override record. General's
three strokes now form a coherent arrow rather than spokes. Private input
notes and rendered output are not distributed.

Corresponding modified source is in this directory in the application source
ZIP, and also in third_party/onenote-parser-source.zip bundled with the app.
The unchanged macro crate's corresponding source URL is in third_party/README.md.

## Kiyobumi 0.7.2 modifications (MPL-2.0)

- TransactionLogFragment and RevisionStore honour Header.cTransactionsInLog;
  undefined bytes after the final committed transaction are not followed.
  Missing or cyclic continuations before the final transaction remain errors.
- FileNode defers revision-manifest-list resolution. FileNodeList resolves only
  the last reference, allowing obsolete references to reclaimed storage.
  An invalid current reference is still an error.
- Five synthetic regression tests cover stale trailing bytes, continuation,
  truncation, obsolete references, and a broken current reference.
- No private notebook data is included in these regression fixtures.

Format references (no implementation code copied):
https://learn.microsoft.com/en-us/openspecs/office_file_formats/ms-onestore/158030a2-dbf0-4b92-bf6e-1a91a403aebd
https://learn.microsoft.com/en-us/openspecs/office_file_formats/ms-onestore/480f3f4d-1c13-4b58-9ee5-63919b17fb11
