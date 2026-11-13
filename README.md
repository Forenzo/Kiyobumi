# Kiyobumi — 清文

**A native, local-first notebook app for macOS, inspired by the freeform notebooks of OneNote.**

Kiyobumi brings notebooks, coloured section tabs and freely arranged pages to a Mac-native interface. Keep lecture notes, project plans, handwritten ideas, tables and reference documents together, with your notebooks saved as files you control. No Microsoft account or hosted service is required.

The name **清文** expresses clear, lucid writing.

## A notebook that gives your ideas room

- **Organise your work:** keep multiple notebooks, coloured covers and section tabs, pages and indented subpages. Search page titles, note text, table cells and attachment names.
- **Write anywhere:** place, move and resize text boxes on a freeform canvas. Format text with fonts, sizes, emphasis, colours, highlights, lists and checkboxes.
- **Let notes grow:** text boxes expand with their content, and optional automatic flow pushes overlapping content below them down.
- **Mix your content:** combine paragraphs, editable tables, images and attachments inside a box, or arrange them as separate page elements.
- **Work with tables:** resize individual columns, grow rows with their contents, shade cells and paste spreadsheet data as an editable table.
- **Draw and annotate:** use the pen, ink highlighter and whole-stroke eraser, including over imported PDF printouts.
- **Make the page your own:** choose plain, ruled or grid paper, colours and margin guides; save reusable page templates.
- **Keep your place:** autosave, visible save status, live word count, editable page headers and an option to reopen the last-used notebook.
- **Read and share:** pinch to zoom, fit the page width, print pages or sections, export PDFs and share a saved notebook through macOS.

## Familiar notebooks, with a little personality

Choose the native **Classic** interface or one of three original retro-patterned themes: **Cinema Confetti**, **Deco Triangles** and **Jazz Swirls**. Their artwork, sidebars and toolbar colours work with Light, Dark or Follow Mac appearance. The themes take inspiration from the classic Mac Kaleidoscope era; notebook paper keeps its own chosen design.

See [theme previews and background](docs/THEMES.md).

## Bring your OneNote notebooks

The included Rust converter imports desktop OneNote files in the **2010–2016 notebook format**:

| File | Import |
|---|---|
| `.one` | A section and its pages |
| `.onetoc2` | Notebook ordering and section references; keep it beside its sections and folders |
| `.onepkg` | An exported notebook package |

Import retains supported text formatting, page titles and ordering, timestamps, subpages, positioned outlines, decoded ink, available images, attachments and text tables. Original files are left untouched, and an import report records omissions.

Import fidelity is still developing: exact layout, rich table-cell formatting, equations, protected sections and revision history are not fully supported. Section groups flatten into path names. Keep the originals and compare imported pages. Live OneNote synchronisation, recording and OCR are not currently available.

## Your notes, stored locally

Notebooks are saved as `.onbook` packages using native macOS document saving and autosave. Images and attachments travel with the notebook. Choose where to keep your files and copy them for backup or transfer.

Kiyobumi is built with **SwiftUI and AppKit**, with a separate **Rust** import helper. It does not bundle a browser engine. The app currently runs on macOS; the converter is portable. Full Japanese interface localisation is planned.

## Get started

The first public release uses **0.7.10**, the latest completed development version. See [Releases](https://github.com/Forenzo/Kiyobumi/releases) for version downloads and [Changelog](CHANGELOG.md) for development history.

### Build on your Mac

Requires **macOS 13+**, **Swift 5.9+ with Apple's tools**, and **Rust 1.89+**. The first build downloads pinned Rust dependencies.

```sh
git clone https://github.com/Forenzo/Kiyobumi.git
cd Kiyobumi
. "$HOME/.cargo/env"
./scripts/build-macos.sh
open dist/Kiyobumi.app
```

To build and install in `~/Applications`, run `./Install-Kiyobumi.command` from the repository folder. For an existing build, `./scripts/install-macos.sh --desktop` installs it and offers a Desktop alias. The installed app runs independently of the source folder.

The build script runs Rust tests, bundles the importer and licences, and ad-hoc signs the app for the current Mac architecture. Optional Swift tests use `./scripts/build-macos.sh --test` and require full Xcode; Command Line Tools can build without that step. Developer ID signing, notarisation and universal builds are future work.

Save and quit the app before updating. Newer notebook features can require a newer file schema, so keep backups before opening them with older versions.

## Project background and development

Kiyobumi is an independent, open-source project inspired by the notebook organisation and freeform page model of desktop OneNote. It is not affiliated with Microsoft. Its native interface and converter are original project code; the OneNote reader includes a documented third-party compatibility patch.

- [Roadmap](docs/ROADMAP.md)
- [OneNote feature coverage](docs/ONENOTE-2010-FEATURES.md)
- [Validation and remaining acceptance checks](docs/VALIDATION.md)
- [Autosave behaviour](docs/AUTOSAVE.md)
- [Contributing](CONTRIBUTING.md)
- [Provenance](docs/PROVENANCE.md) and [third-party notices](third_party/README.md)

Original application and converter code is available under the [MIT licence](LICENSE). The external OneNote reader is **MPL-2.0**; its notices and modified source are included. Kiyobumi remains an early project, and import fidelity and native interaction checks are ongoing.
