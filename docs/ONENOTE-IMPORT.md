# OneNote desktop import in Kiyobumi 0.3.1

The GUI now performs content conversion, replacing the 0.1 header-only action.
The Rust `one-import` executable calls the pinned `onenote_parser` 2.0.0 high-level API with documented
MPL-2.0 fixes in rust/vendor/onenote_parser/PATCHES.md. App/converter code is MIT; this external binary parser and
its macro crate are MPL-2.0. Notices and corresponding-source URLs are included
in the source and bundled application. No Microsoft implementation is linked.

## Target formats

- `.one`: desktop section files, including the shared 2010–2016 version-42 store.
- `.onetoc2`: notebook references/order, with its sibling sections and group folders.
- `.onepkg`: CAB packages containing a table of contents and section files.

OneNote 2010 can still contain a notebook saved in the old 2007 format. Check
File → Info → notebook Settings → Properties → Default Format and convert to
2010 format when needed. A `.onetoc2` is not a copy of the pages: copying only
that file is insufficient.

Microsoft format compatibility:
https://support.microsoft.com/en-us/onenote/file-format-changes-in-onenote-2016-for-windows
Public specs: [MS-ONESTORE], [MS-ONE], [MS-FSSHTTPB].
https://learn.microsoft.com/en-us/openspecs/office_file_formats/ms-onestore/ae670cd2-4b38-4b24-82d1-87cfb2cc3725
https://learn.microsoft.com/en-us/openspecs/office_file_formats/ms-one/73d22548-a613-4350-8c23-07d15576be50
Parser API/source:
https://docs.rs/onenote_parser/2.0.0/onenote_parser/struct.Parser.html
https://github.com/msiemens/onenote.rs/tree/fa4d7a044324af3bfe68727704a9789a08b36a3c

## Conversion map

The converter walks notebook entries, sections, page series, pages, positioned
outlines and their recursive items through the public API. Half-inch layout
units become 48 logical units. Page IDs, element IDs and stored media names are
fresh UUIDs, so repeated imports do not overwrite notes.

Text run indices are interpreted as UTF-16 boundaries. Body text becomes
portable richText values with font names, half-point sizes converted to points,
bold/italic/underline, text colors and permitted web/mail hyperlinks. Hidden
link markers are excluded. To-do tags become ☐/☑ prefixes; other tags become
labels. List outlines gain bullet prefixes; exact source numbering and tag
semantics are approximate. Tables retain text/Markdown cells, not rich font runs.
Extracted image/file payloads remain binary data in the media folder.

Decoded ink from page/outline objects and inline ink outside tables maps to
vector strokes through the reader's public Ink/InkStroke APIs. The mapper does
not independently implement the binary ink decoder. The patched reader reconstructs first-order InkPath deltas before applying
scaling; the mapper uses HIMETRIC conversion (96/2540), normalizes
points relative to their element, and retains color/width/transparency.
Scale and nested/inline positioning remain provisional pending comparison on
actual OneNote pages. Pressure and pen-tip shapes are approximated.

Section groups flatten to names containing their group path. Paragraph heights
and table widths are estimated at import; the Mac editor measures text boxes
with TextKit when displaying them. Exact spacing/alignment, highlight/strikeout,
sub/superscript, equations, non-text table-cell contents, internal OneNote links
and unavailable image data generate issues. Version history, deleted pages and
password-protected sections remain outside this release. Upstream may skip
unreadable sections; review its warning report and page/section counts.
This is not a lossless migration guarantee. Keep the original files.

## Isolation and failure behavior

The Mac UI runs the helper off the main thread in a separate process, with a
90-second timeout. It uses a UUID temporary directory, validates the resulting
`.onbook`, and only then appends sections/pages/media to the current document.
Its conversion report survives later saves as a separate ancillary JSON file.
The original file is read-only and never changed.

Filesystem reads are confined to the selected source directory after symlink
resolution. The parser filesystem cannot write. A package's advertised expanded
size is checked before extraction; the upstream package reader extracts only
into memory. Input/output count and size budgets are described in README.md.
The CLI requires a nonexistent output path and may leave an incomplete new
folder after a failure. The GUI always cleans its staging folder.

Tests include real published version-42 fixtures, equivalence of a native
notebook and an assembled CAB package, missing section diagnostics, malformed
input and preservation of the source. A privately supplied desktop section has been converted and checked for
structure, extracted bytes, font names and decoded ink. This is not an on-Mac
visual comparison or verified complete OneNote 2010 fidelity. See VALIDATION.md.

## 0.3.1 reader and error handling

MS-ONESTORE 2.1.9 permits standalone ObjectInfoDependencyOverridesFND nodes
after root references. The local parser patch accepts these reference-count
records at revision level. They are still decoded, rather than bypassed in
the binary input; they do not alter the read-only object-property snapshot.

The patched ink reader accumulates each X/Y axis independently, resets for
each stroke and rejects integer overflow/incomplete axes. Existing native
ink is not rewritten. Reimport affected OneNote sections to obtain corrected
geometry. The original source files remain unchanged.

Import failure messages now separate the summary from a bounded diagnostic
log in a scrollable sheet. Close remains outside the log and always visible;
Return/Escape dismiss it. The converter still stages and validates the whole
import before merging into the current notebook.
