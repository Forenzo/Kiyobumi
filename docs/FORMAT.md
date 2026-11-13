# Open notebook format, versions 1–4

One notebook is a folder package whose filename ends in `.onbook`:

- `manifest.json`: format ID, schema version, notebook ID/name and ordered sections.
- `pages/<uuid>.json`: exactly one file per referenced page, lowercase UUID filename.
- `media/<opaque filename>`: binary images and attachments; no external path references.

JSON is UTF-8. Identifiers are standard UUID strings, interpreted case-insensitively.
Page filenames use lowercase UUIDs. Dates are RFC3339 UTC, whole-second ISO8601
strings. Coordinates are finite numbers in logical canvas units, 96 units per
inch, with x rightward and y downward. Ink samples are relative to their element's
frame. Widths and heights are nonnegative; stroke widths must be positive.
Pressure is normalized to 0…1. Colors are RGB `#RRGGBB`. A v3 stroke may include `opacity` in 0…1;
when omitted, pen/highlighter opacity uses the existing renderer policy.

The `sections` array orders sections; a section's `pageIDs` array orders pages.
Every page belongs to exactly one section. Duplicate section/page/element IDs,
missing files, orphan page files, malformed page JSON, missing referenced images
and unknown element discriminators fail opening/saving. There is no silent
best-effort page loss. A future recovery tool should copy recoverable data to a
new notebook with an explicit report.

The manifest has exactly one content authority: pages are not embedded in it.
Element content uses explicit discriminators:

```json
{"type":"text","markdown":"A note"}
{"type":"ink","strokes":[]}
{"type":"image","mediaName":"opaque-image.png"}
{"type":"attachment","mediaName":"opaque.bin","fileName":"notes.pdf"}
{"type":"table","rows":[["A","B"],["C","D"]]}
```

`docs/notebook.schema.json` describes manifest/page structures. Application code
also checks relationships across files, finite values and attachment presence.
Schema validation alone cannot enforce these cross-file constraints.

Writers must not open newer schema versions for editable use. The v0.1 reader
rejects newer versions and unknown element types. It preserves media wrappers
and extra top-level package files. Unknown fields inside known JSON objects are rejected before decoding, because
Swift Codable would otherwise discard them on save. Extensions that require
preservation must use a future version until the codec gains explicit extension
dictionaries. The schema also disallows undeclared fields in known objects.

New applications can read this format without Apple serialization. The native
format does not embed NSAttributedString, NSImage, PencilKit archives, or OneNote
binary storage. Attachment bytes remain their original file encoding.

SwiftUI FileDocument provides the native save integration. Package updates are
not a CRDT or a transaction protocol across machines. Crash recovery, checksums,
revision journals, migrations and concurrent writer controls are future core work.

## Version 2 migration

0.2 reads both manifest versions 1, 2 and 3, and writes 2. Page objects gain
`level` (integer 0–2, visual subpage indentation) and `background` (`plain`,
`ruled`, `grid`). When reading old pages, omitted values default to 0/plain.
Tables and attachment elements use the discriminators above. Table rows must
form a nonempty rectangular matrix of strings, with up to 1,000 rows, 100
columns and 20,000 cells. Cell strings use the same Markdown renderer as text.
`fileName` is a display/export name, never a package storage path.

0.1 rejects version 2, so migration is forward-only for that old client. Extra
package files and media are immutable value snapshots while the document is in
memory, converted back to FileWrapper only for native serialization. Import
reports live in ancillary JSON files and survive native read/save.

## Version 3: portable styled text and ink opacity

Kiyobumi 0.3 reads versions 1–3 and writes 3. The body text element can be:

```json
{"type":"richText","value":{"text":"清文 😀","runs":[],"defaultFormat":{"fontName":"Helvetica","fontSize":14,"bold":false,"italic":false,"underline":false,"colorHex":"#111111"}}}
```

`text` contains the entire Unicode string, including trailing newlines. The
box frame does not limit what is serialized. `defaultFormat` styles uncovered
characters and future typing. Each run has `location`, `length` and `format`;
ranges are UTF-16 code units, not bytes or grapheme counts. Runs must lie inside
the string, with positive lengths and at most 100,000 runs per box. Later runs
override earlier runs for intersecting attributes. Font size is 6…288 points;
fontName is the requested family or PostScript name. Missing fonts are visually
substituted without replacing the saved requested name. Optional `link` accepts
only http/https/mailto URLs. No RTF or opaque NSAttributedString archive is stored.

The old `text`/`markdown` discriminator remains readable. Legacy Markdown is
displayed as styled text, and converts only when that box is edited, formatted
or its checkbox toggled. Layout measurement alone does not rewrite its text.
Table cells retain Markdown strings and do not yet use styled runs.

Ink gains optional numeric opacity in 0…1, where 0 is invisible and 1 opaque.
Old strokes without it keep their previous native pen/highlighter defaults.
Single-point strokes remain valid. Pressure is retained as a portable field
but the native renderer does not yet vary width by pressure.

OpenNotebook 0.1/0.2 readers reject schema 3. Keep a backup before saving in
Kiyobumi if those older versions must still open the notebook.

## Optional page subheaders (Kiyobumi 0.3.4)

Subheaders use the optional top-level ancillary file kiyobumi-page-headers.json:

```json
{"format":"org.kiyobumi.page-headers","version":1,"subheaders":{"5181ac4a-1fdb-4bc0-984f-c2c47ea45117":"Optional text"}}
```

Keys are lowercase page UUIDs; values are plain Unicode strings. Empty values
are removed by the UI. Duplication copies the subheader to the new page ID;
deleting pages/sections removes their entries. When no entries remain, the
metadata file is removed. It does not change page titles or body coordinates.
See page-headers.schema.json. Unknown metadata versions/fields are preserved
by the document codec and rejected for editing by the subheader controller.

The manifest and page JSON remain schema 3. Earlier Kiyobumi versions preserve
the extra package file even though they do not display/edit its subheaders.

## Version 4 editor metadata

Kiyobumi 0.4.0 reads versions 1–4. A save uses v4 if any element contains
`minimumHeight`, `tableColumnWidths`, or any rich-text format contains
`highlightHex`; otherwise it continues writing v3. Earlier clients reject v4.
All added fields are optional; absence preserves the older decoding behavior.

- `element.minimumHeight`: finite nonnegative logical height, at most 1,000,000.
  Content can grow past this floor, so resizing never removes or hides text.
- `element.tableColumnWidths`: positive finite width weights (at most 1,000,000
  each), one per column; valid only on tables. Rendering reserves 48 logical
  units per column and distributes surplus width according to these weights.
  A divider drag stores the new surplus widths. Whole-table resizing retains
  the proportions and a readable minimum column width.
- `textFormat.highlightHex`: RGB background color `#RRGGBB`. Missing means no
  highlight. Each explicit run completely specifies its style, so an
  unhighlighted run can override a highlighted default format.

Printouts use the existing `image` discriminator and an opaque `.pdf` media
filename containing one PDF page. No external file reference or executable
object is stored. Text/document imports are rendered into these PDF media pages.
Source PDF sheets are stored separately, so shared PDF resources can repeat
across sheets. This preserves vector content without rasterizing whole pages.
