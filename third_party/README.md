# Third-party dependencies

The Kiyobumi application/converter source is MIT. Its import helper uses
**onenote_parser 2.0.0 with Kiyobumi's MPL-2.0 compatibility patches**, and
unmodified **onenote_parser-macros 2.0.0** under MPL-2.0. License: MPL-2.0.txt.

Corresponding modified reader source is supplied as onenote-parser-source.zip
in this directory, also bundled in the application. In the full source package
it is rust/vendor/onenote_parser; PATCHES.md records modifications and references.
The application's rust/Cargo.lock pins the dependency graph.

Original source and the unchanged macro crate source:
- https://crates.io/api/v1/crates/onenote_parser/2.0.0/download
- https://crates.io/api/v1/crates/onenote_parser-macros/2.0.0/download
- https://github.com/msiemens/onenote.rs/tree/fa4d7a044324af3bfe68727704a9789a08b36a3c

The parser is external open-source code, not code independently authored by this project.
Cargo.lock pins the complete dependency graph. License copies follow below; target-specific
packages are listed conservatively even if they are not linked on macOS. No AGPL test fixtures
are distributed. See docs/PROVENANCE.md for the separate MIT/MPL fixture attributions.

| Package | Version | SPDX license |
|---|---|---|
| adler2 | 2.0.1 | 0BSD OR MIT OR Apache-2.0 |
| aho-corasick | 1.1.5 | Unlicense OR MIT |
| autocfg | 1.5.1 | Apache-2.0 OR MIT |
| bumpalo | 3.20.3 | MIT OR Apache-2.0 |
| byteorder | 1.5.0 | Unlicense OR MIT |
| bytes | 1.12.1 | MIT |
| cab | 0.6.0 | MIT |
| cfg-if | 1.0.5 | MIT OR Apache-2.0 |
| core_detect | 1.0.0 | MIT/Apache-2.0 |
| crc32fast | 1.5.2 | MIT OR Apache-2.0 |
| deranged | 0.5.8 | MIT OR Apache-2.0 |
| either | 1.19.0 | MIT OR Apache-2.0 |
| encoding_rs | 0.8.42 | (Apache-2.0 OR MIT) AND BSD-3-Clause |
| enum-primitive-derive | 0.3.0 | MIT |
| flate2 | 1.1.10 | MIT OR Apache-2.0 |
| foldhash | 0.2.0 | Zlib |
| futures-core | 0.3.34 | MIT OR Apache-2.0 |
| futures-task | 0.3.34 | MIT OR Apache-2.0 |
| futures-util | 0.3.34 | MIT OR Apache-2.0 |
| getrandom | 0.4.3 | MIT OR Apache-2.0 |
| hashbrown | 0.17.1 | MIT OR Apache-2.0 |
| itertools | 0.14.0 | MIT OR Apache-2.0 |
| itoa | 1.0.18 | MIT OR Apache-2.0 |
| js-sys | 0.3.106 | MIT OR Apache-2.0 |
| libc | 0.2.190 | MIT OR Apache-2.0 |
| log | 0.4.34 | MIT OR Apache-2.0 |
| lru | 0.18.5 | MIT |
| lzxd | 0.2.7 | MIT OR Apache-2.0 |
| memchr | 2.8.3 | Unlicense OR MIT |
| miniz_oxide | 0.9.1 | MIT OR Zlib OR Apache-2.0 |
| multiversion_no_op | 1.0.0 | Apache-2.0 OR MIT |
| num-conv | 0.2.2 | MIT OR Apache-2.0 |
| num-traits | 0.2.19 | MIT OR Apache-2.0 |
| once_cell | 1.21.4 | MIT OR Apache-2.0 |
| onenote_parser | 2.0.0 | MPL-2.0 |
| onenote_parser-macros | 2.0.0 | MPL-2.0 |
| pin-project-lite | 0.2.17 | Apache-2.0 OR MIT |
| powerfmt | 0.2.1 | MIT OR Apache-2.0 |
| proc-macro2 | 1.0.107 | MIT OR Apache-2.0 |
| quote | 1.0.47 | MIT OR Apache-2.0 |
| r-efi | 6.0.0 | MIT OR Apache-2.0 OR LGPL-2.1-or-later |
| regex | 1.13.1 | MIT OR Apache-2.0 |
| regex-automata | 0.4.18 | MIT OR Apache-2.0 |
| regex-syntax | 0.8.11 | MIT OR Apache-2.0 |
| rustversion | 1.0.23 | MIT OR Apache-2.0 |
| sanitize-filename | 0.6.0 | MIT |
| scopeguard | 1.2.0 | MIT OR Apache-2.0 |
| serde | 1.0.229 | MIT OR Apache-2.0 |
| serde_core | 1.0.229 | MIT OR Apache-2.0 |
| serde_derive | 1.0.229 | MIT OR Apache-2.0 |
| serde_json | 1.0.152 | MIT OR Apache-2.0 |
| simd-adler32 | 0.3.10 | MIT |
| simdutf8 | 0.1.5 | MIT OR Apache-2.0 |
| slab | 0.4.12 | MIT |
| syn | 2.0.119 | MIT OR Apache-2.0 |
| syn | 3.0.7 | MIT OR Apache-2.0 |
| thiserror | 2.0.21 | MIT OR Apache-2.0 |
| thiserror-impl | 2.0.21 | MIT OR Apache-2.0 |
| time | 0.3.55 | MIT OR Apache-2.0 |
| time-core | 0.1.9 | MIT OR Apache-2.0 |
| time-macros | 0.2.32 | MIT OR Apache-2.0 |
| typed-path | 0.12.3 | MIT OR Apache-2.0 |
| unicode-ident | 1.0.26 | (MIT OR Apache-2.0) AND Unicode-3.0 |
| uuid | 1.28.0 | Apache-2.0 OR MIT |
| wasm-bindgen | 0.2.129 | MIT OR Apache-2.0 |
| wasm-bindgen-macro | 0.2.129 | MIT OR Apache-2.0 |
| wasm-bindgen-macro-support | 0.2.129 | MIT OR Apache-2.0 |
| wasm-bindgen-shared | 0.2.129 | MIT OR Apache-2.0 |
| widestring | 1.2.1 | MIT OR Apache-2.0 |
| zmij | 1.0.23 | MIT |

Additional development-only dependencies for the parser's upstream unit tests:
tempfile 3.27.0, bitflags 2.13.2, errno 0.3.14, fastrand 2.5.0,
linux-raw-sys 0.12.1, rustix 1.1.5, windows-link 0.2.1 and windows-sys 0.61.2.
These are not linked into the shipped import executable; registry license
copies are in licenses/ where applicable.
