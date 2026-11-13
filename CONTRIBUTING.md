# Contributing to Kiyobumi

Kiyobumi is an early native macOS notebook editor with a Rust OneNote importer.
For bugs, include the app version, macOS version, steps to reproduce, and expected
behavior. Remove private notebook content and personal information from reports.
Use a small synthetic notebook when possible.

Build instructions are in README.md. On a Mac with full Xcode, run
`./scripts/build-macos.sh --test`. For importer changes, run
`cargo test --manifest-path rust/Cargo.toml --locked` and the import smoke test
in the existing source-check workflow. Report which checks you actually ran.

Keep changes focused and preserve notebook compatibility, autosave, and editing
behavior. Include regression tests for bugs where practical. Document any schema
changes and migration behavior. See docs/VALIDATION.md for known testing limits.

Follow docs/PROVENANCE.md for source and fixture provenance. Preserve MIT and
MPL-2.0 notices; document changes to the vendored parser in its PATCHES.md.
Do not add proprietary source or notebooks without permission to redistribute them.
