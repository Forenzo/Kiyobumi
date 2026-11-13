# Source and fixture provenance

The Swift editor began with the user-supplied AI-generated blueprint and was
adapted for native documents, explicit JSON, validation and editor behavior.
The Rust `onestore` preflight code was independently written from the published
Microsoft file specifications. The new `one-import` content mapper is original
project code that consumes an external open-source reader through its public API.
No proprietary OneNote implementation, disassembly, leaked source, Microsoft
branding or copied product artwork is used.

## External reader

`onenote_parser` and `onenote_parser-macros` are pinned to 2.0.0. The crates record
upstream commit `fa4d7a044324af3bfe68727704a9789a08b36a3c` in the
https://github.com/msiemens/onenote.rs repository. The macro crate is unmodified MPL-2.0 code. The reader now carries
small, documented MPL-2.0 compatibility changes in rust/vendor/onenote_parser,
with PATCHES.md identifying modified files, structure references and tests. This project's author does **not** claim to have independently implemented
that reader, or to have audited the provenance of every upstream contribution.
Upstream describes published-spec parsing plus work on undocumented ink/math.
Kiyobumi 0.3 maps decoded ink through that reader's public API; it does not
claim independent authorship of the binary ink decoder. Math remains omitted.

`third_party/README.md` lists dependencies and corresponding-source download URLs;
`third_party/MPL-2.0.txt` and `third_party/licenses/` contain license copies.
These notices are bundled alongside the import executable. MIT applies to the
original application/converter code, not every dependency. Cargo.lock pins the
resolved versions; the patched parser source is distributed and bundled separately under MPL-2.0.

## Distributed test fixtures

- `rust/one-import/tests/fixtures/mit/OneWithFileData.one`: published OfficeDev
  Interop-TestSuites sample, obtained through the upstream parser fixture tree.
  MIT, copyright 2015 Office; the original notice is beside it.
- `rust/one-import/tests/fixtures/notebook/`: upstream `non-legacy` native
  notebook samples at the pinned commit above. MPL-2.0; license beside them.
- CAB test archives are assembled temporarily from these existing fixtures,
  not exported by Microsoft's application during this development session.
- `examples/*.onbook`: project-authored native-format examples.

A separate Joplin-derived AGPL desktop fixture was used for an internal manual
conversion check. Neither it nor its converted contents are distributed in this
source package. Parser test fixture trees have mixed licenses; do not indiscriminately
copy them into this project.

## Contributor rule

Use published specifications, independently written code, and documented
application behavior. Record new dependencies' licenses and source provenance,
and record each fixture's origin. Do not call imported OSS code independently
implemented or promise full fidelity from a passing header check.

This is an independent open-source implementation with third-party OSS
components. It is **not** a certification that a formally segregated clean-room
process has been completed, or that upstream has followed such a process.
Kiyobumi / 清文 is the user-selected name. Its display name is localized; the
original bundle ID remains stable. No registration or clearance claim is made.
