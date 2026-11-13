# Roadmap after Kiyobumi 0.3

0.2 adds desktop content conversion through an external OSS parser, expanding
page bounds, fit width, tables, checklist toggles, attachments, text search,
subpage indentation and section/page management. It remains an early Mac release.

1. Validate the build and narrow-window/zoom behavior on actual Apple Silicon
   and Intel Macs. Test the user's own non-sensitive OneNote 2010 exports.
2. Refine paragraph flow, rich table cells, source numbering/tag semantics,
   font fallback and image/OCR text preservation. The portable styled-run model
   is now implemented for body text boxes.
3. Compare ink scale/placement/pressure with actual source pages and improve
   section groups, table-cell objects and import diagnostics. Source ink is
   now mapped through the external reader; it is not independently decoded.
4. Add persistent page history, recovery/deleted-item workflows, export and
   accessibility. Current page undo is memory-only and resets when switching pages.
5. Extract canonical storage/validation into Rust, retaining explicit migrations
   and opaque extension preservation for future clients.
6. Build Windows/Linux native shells against the same shared core. Design sync
   with revisions, conflicts/tombstones and attachment consistency before claiming
   that cloud-folder mirroring is safe collaboration.

No date-based parity promise is assigned before real notebook fidelity and
Mac interaction checks have been completed.
