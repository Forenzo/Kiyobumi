# Changelog

Development history leading up to the first public release, **0.7.10**. Earlier entries describe their state at the time.

## 0.7.10 — text undo crash repair

Text boxes and table cells now own separate native undo managers. Removing an editor clears its undo/redo entries, and loading a page snapshot clears text operations that no longer match its content. This addresses a suspected stale text-undo target behind the supplied Command-Z crash; the report cannot identify the target conclusively. Page-action toolbar history remains unchanged. Text undo history is local to the editor and is not retained across editor removal/page switches.


## 0.7.9 — Complete top-bar colors

Toolbar control groups now use lighter theme-colored panels with coordinated
borders. The section-tab strip and native window-toolbar background also request
theme colors. Dark-mode sidebar actions use brighter lavender or mint accents
for readability. Classic retains native styling; notebook paper is unchanged.


## 0.7.8 — Coordinated sidebar colors

Both notebook/section and page sidebars now use solid colors from the selected
pattern: midnight blue/violet for Cinema Confetti, teal for Deco Triangles and
plum for Jazz Swirls. The page column uses a slightly lighter shade. Light mode
uses pale versions of the same palette, while dark mode uses deeper shades.
Sidebar accents follow the theme. Classic restores native sidebar styling.


## 0.7.7 — Retro patterned themes

Settings > Appearance > Theme adds Cinema Confetti, Deco Triangles and Jazz
Swirls, plus Classic to return to the plain interface. Each has its own repeating
geometric artwork, preview card, textured workspace/toolbar and notebook trim.
Theme selection is remembered and works independently of Light/Dark/Follow Mac.
Toolbar controls stay on solid raised panels and paper stays clear for writing.
These are original Kiyobumi themes inspired by inspected Kaleidoscope archive
references; see docs/THEMES.md for previews, provenance and editable assets.
The confirmed two-finger click implementation and import repairs are retained.


## 0.7.6 — Interface appearance

Kiyobumi > Settings > Appearance offers Follow Mac, Light and Dark. The choice
applies immediately across the app and is remembered between launches. Follow
Mac is the default and follows the system's appearance changes.

The toolbar, navigation, settings and native dialogs use the selected appearance.
Notebook paper keeps its selected color, and text, ink and images retain their
original colors. This is interface dark mode; it does not recolor notebook pages.
Native text editors keep a light-paper appearance so the caret stays readable.
The confirmed two-finger click implementation and OneNote import fix are retained.


## 0.7.5 — Native secondary-click routing

Replaces the passive click monitor with a native secondary-click target on blank
paper. Right-click, two-finger secondary click and Control-click create a box.
Normal left-clicks pass through. Large ink-container bounds no longer block box
creation on imported pages. Existing text/table/image regions remain protected.

If clicks still fail, quit Kiyobumi, run `./scripts/debug-clicks.sh`, then try the
click again and copy the `KiyobumiClick` terminal lines. This opt-in diagnostic
prints event types and geometry, never notebook text. The native fix and new
AppKit tests still require validation on macOS.


## 0.7.4 — Two-finger click creates text boxes

Two-finger secondary-click on blank paper now creates a text box at the pointer
and enters text editing. A mouse right-click or physical middle-click also works.
Clicks within existing elements, selected resize areas and floating table controls
pass through to their usual handlers. The accepted click's release is consumed
so it does not open a context menu on the newly created box.
The OneNote import fixes from 0.7.2 are retained.


## 0.7.3 — Middle-click canvas repair

The middle-click listener now has an explicit canvas size and lives in a
transparent overlay. Its event monitor follows attachment to the window and
checks the scroll viewport before creating a text box at the click position.
Normal text/ink hit testing passes through the overlay. The 0.7.2 import repair
is retained. Native macOS mouse testing is still required.


## 0.7.2 — OneNote import repair

Fixes an “Unexpected end of file” failure on valid desktop OneNote sections.
The reader stops at the committed transaction count and ignores obsolete
revision-list pointers before resolving the current revision. Regression tests
cover both conditions and still reject a broken current revision.
The supplied test section imports eight pages, one image and 3,188 ink strokes.
This repairs parsing; complete layout and formatting fidelity remain ongoing work.


## 0.7.1 middle-click text boxes

Press the mouse wheel/middle button over the page body to create a text box at that position and start typing. It uses the chosen font and size, the usual initial box dimensions, autosave and undo. Works regardless of the selected drawing tool. The header, toolbar and sidebars are excluded; dialogs and print/import work block insertion. Side mouse buttons and wheel scrolling retain their existing behaviour.


## 0.7.0 tables, paper design and templates

- Right-click a table cell → **Cell shading** for yellow, green, blue, pink, grey, white or no fill. Works in standalone and embedded tables, including while typing. Shading follows the cell into PDF/print output.
- **Insert → Table from clipboard…** converts tab-separated spreadsheet/text data into an editable table at the text insertion point or on the canvas. Quoted tabs/newlines and escaped quotes are supported; ragged rows are padded. Limits: 1,000 rows, 100 columns, 20,000 cells, 10 MB input.
- Toolbar sliders menu → **Page design…** sets plain/ruled/grid paper, rule spacing (8–96 points), paper/rule colours, and optional margin position/colour. Apply is undoable. Margins are guides rather than text constraints. Header and body share the paper colour; PDF/printing preserves the design.
- Same menu → **Page templates…** offers Plain, Ruled and Grid starters. Name and save the current page to keep its content, tables, formatting, attachments, subtitle and paper design. Select a template and **Create page** to add an independent copy to the current section. Delete removes the saved template only.
- Custom templates live in `~/Library/Application Support/Kiyobumi/Templates` as self-contained notebook packages. Copy that folder when backing up templates or moving to another Mac. Templates are not notebook backups or page history.

Existing notebooks remain readable. Paper design or cell shading uses **schema 6** when saved; older app versions cannot open those notebooks. Keep a copy before trying the update. Existing macOS 27 build configuration and Rust importer are unchanged.

This build does not add rich formatting within individual table cells or Apple Notes exchange yet. Cells retain their existing text/Markdown editing behaviour.

Validation here: Swift syntax parsing and archive checks. macOS compilation, XCTest and native interaction testing require a Mac; see `docs/VALIDATION.md` for acceptance steps.


## 0.6.2 delete selected internal blocks

Click an internal table's outside border, then press Delete or Forward Delete to
remove that table. Block options also provide Select block. This selection is
separate from cell editing: Delete in an editable cell still deletes characters.
The same selection applies to internal images, attachments and paragraph blocks.
Surrounding blocks stay intact and flow up into the vacated space; removing the
only block leaves an empty editable paragraph. The outer box remains intact.


## 0.6.1 table sizing and last-used notebook

Embedded tables retain their own width instead of filling the entire paragraph
container. Dragging a column narrower now stays narrow, including after the
surrounding text box grows. Existing stretched tables can be resized normally.

Reopen the last-used notebook is enabled by default in Settings. The application
remembers saved notebooks as their windows become active, including switches to
already-open notebooks, and updates the remembered location after renaming.
Disable this setting to use the previous specific-startup-notebook selection.
The pinned choice remains stored separately and is also a first-launch fallback
until a last-used notebook has been recorded. Option-launch and explicit Finder
opens retain their existing behaviour. Missing startup files lead back to the
notebook collection after an error message, without silently forgetting the file.


## 0.6.0 mixed-content text boxes

While editing a paragraph, use Insert > Table, Image, Attachment or Document
printout. The item is placed at the cursor with editable text above and below it.
When no paragraph is active, these commands still create standalone page items.
The box is an ordered vertical sequence: text does not wrap alongside images.

Click a paragraph or table cell to edit it. Text growth, extra table rows and image
size changes move the following blocks down. Drag the outer border to move the
whole box. The optional push-content setting also makes room among other page
boxes. A small block-options menu beside each block appears while editing:
add/remove table rows or columns, change image size, save an attachment, or remove
a block. Independent table-column dragging remains available after clicking a cell.

Embedded items use the same media storage as standalone items. Search, word count,
PDF export and printing include mixed content; attachments print their filename.
Each paragraph block is edited separately (click between blocks; Backspace does
not merge paragraphs across an embedded item). Nested tables/boxes and moving
existing standalone items into a box by drag-and-drop are not included.

Tests cover formatted/Unicode splitting, sequential layout, media round trips,
validation and PDF text. Static Swift parsing and archive checks are available in
the packaging environment; native compilation, XCTest and visual checks require
macOS and have not been run here. The confirmed 0.5.7 build setup is preserved.


## 0.5.9 automatic content flow

Settings > Editing now offers Automatically push content down (on by default).
While editing, growing text boxes and tables push horizontally overlapping boxes
below them down, with a 12-point gap. Movement propagates through lower boxes;
side-by-side notes remain independent. Shrinking text leaves positions unchanged.
Manual dragging/resizing and opening a notebook do not trigger flow. Ink remains
at its original page coordinates. Moved positions participate in the existing
page undo snapshot and autosave. No notebook format change is required.


## 0.5.8 pasted text and section colours

Pasted rich text now uses the same supported formatting for native display,
box sizing and saving. Clipboard-only paragraph spacing and text-table layout
are normalized so they cannot overflow the calculated box and page height.
Text, supported fonts, sizes, emphasis, colours and links are retained.
Yellow is available in the section colour menu. The confirmed 0.5.7 build
configuration is unchanged.


## 0.5.7 rebuild and canvas regression fixes

Builds explicitly use the previous native SwiftPM backend, a fresh Swift build
folder and the SDK resolved by xcrun. The new default SwiftBuild backend appeared
in the failing Swift 6.4 log; this change removes that variable. The same options
are used for compilation, tests and locating the binary. Rust caches are retained.
The packaged app records DTSDKName/DTPlatformVersion and compiler/Mach-O details
in Contents/Resources/BuildInfo.txt. A deployment target of macOS 13 is retained.

The canvas explicitly scrolls to the page's top-left after appearing, to expose
the title/date/subtitle header instead of relying on initial scroll defaults.
The Share application menu and compact section dropdown from 0.5.6 are included.

Static syntax and archive checks passed; native Mac building and visual checks
remain necessary. The build-backend explanation is a hypothesis supported by
the log, not a confirmed cause of every styling difference. Compare the rebuilt
app with the older working app on the same Mac: window/toolbar styling, menus,
first page header, scrolling, zoom and switching pages/notebooks. If appearance
still differs, preserve BuildInfo.txt for checking the executable's SDK metadata.


## 0.5.6 Share application menu

Share is now a text menu beside the application's File/Edit/View/Window menus.
Choose Share > Share Notebook to open the native sharing options after saving.
The system status icon has been removed. The section dropdown is explicitly
restricted to 32 points to prevent stretching with the newer SDK's menu style.
Other visual differences under macOS 27 remain under investigation; this update
does not claim to restore all prior styling. Syntax and archive checks only:
native build, menu interaction, AirDrop and visual testing remain pending.


## 0.5.5 SDK 27 State compatibility

App state declarations use `@KiyobumiState`, a type alias for the existing
`SwiftUI.State<Value>` property wrapper. This avoids resolving the new SDK 27
`State` macro when its SwiftUIMacros plugin is unavailable in standalone Command
Line Tools. The alias preserves the original SwiftUI state storage and bindings;
it does not implement a replacement state system. Native SDK 27 build confirmation
is pending. Other property wrappers and notebook formats are unchanged.


## 0.5.4 system menu-bar sharing and notebook filenames

Share is now a square-and-arrow icon in the system menu bar alongside macOS
status icons, outside the notebook window. It shares the active saved Kiyobumi
notebook after saving edits. macOS chooses the available sharing destinations.

Edit the notebook heading and press Return or click away to rename its `.onbook`
file in the same folder. Existing filename conflicts produce an error; choose
a different name. Invalid filename characters are rejected. The notebook list
and startup bookmark are updated after a successful move, and the internal
notebook name is saved. Unsaved notebooks need to be saved before renaming.
For an existing name/filename mismatch, focus the heading and press Return even
without changing the text. Simply opening a notebook does not rename its file.

The default SwiftUI title item is removed on macOS 26 with Swift 6.2+; the AppKit
window title is kept hidden on older configurations and after document updates.


## 0.5.3 alignment and native sharing

The word-count item tracks the page column width and centres its text in that
space. The notebook heading uses the same leading inset as the collection label.
The page column's preferred starting width is now its 180-point minimum; it
remains manually resizable up to 360 points.

A Share button in the window toolbar saves the current notebook through its
native document, then opens the macOS share sheet with the `.onbook` package.
Available destinations depend on macOS and the file type (including AirDrop
where available). Unsaved notebooks must be saved once before sharing. A save
failure shows an error instead of sharing an outdated file. This shares the
whole notebook; PDF export remains available separately for pages and sections.


## 0.5.2 notebook switching

Notebook windows are loaded without display, positioned before being shown,
and switched without native window animations. The previous window stays
visible until the destination is brought forward, avoiding the old frame jump.


## 0.5.1 word-count position

Moved the word count from the centred window toolbar to its leading navigation
area, above the page list where the file title previously appeared.


## 0.5.0 notebooks, word count and spelling

The sidebar now holds a remembered collection of notebooks with coloured covers:
open for the current notebook, closed for the others. The editable notebook name
stays above the collection; the duplicate floating file title is hidden.
File > New Notebook creates a named `.onbook` in Documents/Kiyobumi Notebooks.
Change the folder in Settings; this affects new notebooks, without moving old ones.
Existing files can be added with Open Notebook. Duplicate filenames get a numeric
suffix. Right-click a notebook to change its cover colour, reveal its file or
close it from the collection. Closing never deletes its saved file. Editing the
display name does not rename the underlying file.

Switching brings the selected native document forward and hides the previous
notebook window, preserving its page selection and macOS-managed autosave.
Full-screen windows retain normal macOS window/space behaviour. The collection
is remembered locally between launches. The existing startup-notebook setting
still applies; otherwise the collection chooser appears.

The former title area displays the current page's live word count, including
its title, subtitle, text boxes and table cells. Formatting and link targets are
excluded; images, ink, PDF printouts and attachment contents are not OCR-counted.
Apple's language-aware word tokenizer determines boundaries, which can differ
from other word processors, especially for Japanese and compound words.

Native Apple spell-check is enabled by default in note text and table cells.
Control-click a misspelling for suggestions, or use Edit > Spelling and Grammar.
Automatic correction is not forced on. Language/dictionary selection follows
macOS spelling settings. No separate dictionary download is bundled.


## 0.4.9 smaller starting text boxes

New text boxes start at 160 points wide instead of 320. Automatic horizontal
growth still applies as you type. Existing boxes keep their saved widths.


## 0.4.8 tighter page header

Reduced the space beneath the subtitle by one ruled line (28 points). Long titles
still receive room for a second line. Subtitle text now uses the same secondary
grey as the date/time, including while editing; an empty subtitle stays blank.
PDF exports use the same shorter header and grey supporting text. Existing page
objects retain their positions relative to the working area.


## 0.4.7 text boxes grow horizontally

Typing or pasting longer text widens ordinary text boxes to fit the longest
explicit line. Return still creates a new line and increases height. Changing
font size can widen a box too. Existing boxes are not widened merely by opening
a notebook; the growth happens on edits. Deleting text does not collapse the
width. Manual narrowing is still possible, but another text edit can widen it
again. Table columns remain under independent manual width control and wrap.
The canvas expands with the box, and the existing 100,000-point width limit applies.


## 0.4.6 one-click highlighting and text editing

The text highlighter is now a split control: click its main icon to apply the
remembered colour (yellow initially), or remove an active highlight. Its small
arrow opens the colour menu. Picking a colour applies it and remembers it for
later clicks, including after relaunch.

Click directly inside a text box to place the caret and start typing. Drag inside
text to select characters. Hover a text/table box to see its outline; drag the
outer border to move it. Border clicks select the box, allowing whole-box
formatting or Delete. Resize handles retain their existing function. The Text
tool also edits existing text when clicked; clicking blank canvas creates a box.
Table single-click editing, arrow navigation and automatic row sizing remain.


## 0.4.5 table arrow navigation

Click a cell and use the arrow keys. Left at the start of its text moves to the
previous column; Right at the end moves to the next column. Up on the first
visual line moves to the row above; Down on the last visual line moves below.
Wrapped lines count as visual lines. Empty cells can move in all four directions.
Moving left/up enters at the end of the destination text; right/down enters at
the start. At the table edge, arrows keep their normal text-editing behaviour.
Shift/Option/Command/Control arrow combinations and IME composition retain native
editing behaviour. Return still adds a line inside the current cell.


## 0.4.4 direct cell editing and automatic table height

Click once in a table cell to start typing. Return/Enter inserts a newline; rows
expand with new lines or wrapped text and shrink when that text is deleted.
The cell editor now uses native NSTextView instead of a submitting TextField.

Row/column buttons float above the table, outside its measured bounds. Showing
or hiding them no longer shifts cells or changes table height. Table height is
entirely content-driven, including tables with older manually stretched heights;
tables retain horizontal resize handles but no vertical corner handle. Other
text/image box height controls are unchanged. Native column handles now own both
mouse tracking and the horizontal resize cursor.


## 0.4.3 compact table rows and resize cursor

Empty and single-line rows now use one line of text with a small vertical inset.
Only rows containing wrapped text or extra lines grow taller; deleting that text
shrinks them again. PDF export and printing use the same spacing. In 0.4.3, an explicitly
set minimum table height still applied (removed for tables in 0.4.4). Column borders show a horizontal resize
cursor while editing a table.


## 0.4.2 images and independent table columns

Image and Attachment now use the same native file chooser as Document printout.
Inserted images are selected and brought into view.

Double-click a table to edit it, then drag the highlighted right edge of any
column, including the last column. Only that column changes width; columns to
its right move over without changing size. The table grows or shrinks to fit.
Adding/removing a column preserves the surviving column widths. Whole-table
resize handles still scale columns together. Save/reopen and PDF output retain
the widths using the existing schema-4 representation.


## 0.4.1 document printout picker fix

Document printout now opens a dedicated native macOS file chooser instead of
sharing SwiftUI file-import presentation with Image and Attachment. Preparing
pages uses an in-editor progress overlay with Cancel. After insertion, the first
printout is selected and scrolled into view, and a small dismissible notice shows
the number of pages added. Cancelling the chooser leaves the notebook unchanged.


## 0.4.0 editing, printouts and installation

- Select a text box or table and drag the right-edge handle to change width,
  or the bottom-right handle to change width and minimum height. Text wraps
  live; boxes and tables grow to keep all their contents visible. Use the page
  Undo/Redo buttons to reverse a resize. Images and printouts also have handles.
- Double-click a table to edit. Its grid has stronger borders and more cell
  padding. Drag a highlighted vertical divider to resize its left column independently;
  whole-table resizing preserves their proportions. Row heights grow with
  content and extra requested height. Column widths and box height persist.
- Select a box on the canvas and press Delete or forward Delete to remove it.
  While editing text, Delete continues to remove characters. Search/title/table
  fields keep their normal keyboard behavior. The page Undo button restores a
  deleted element.
- The highlighter menu beside Text color applies yellow, green, pink or blue
  backgrounds to selected characters, a selected whole box, or subsequent text.
  Remove highlight clears it. This is separate from the freehand ink highlighter.
- **Insert (+) > Document printout…** accepts PDF, DOC, DOCX, ODT, RTF, TXT and
  Markdown. PDF pages remain vector PDF media; each appears as a visible page
  on the canvas below existing content. You can move/resize them, write over
  them with ink, and add text boxes on top. Imports prepare completely before
  insertion, support cancellation, and leave the source file untouched.
- Word/ODT/RTF/text printouts use macOS's document reader and reflow onto A4 pages.
  Complex layouts, embedded objects, fonts, footnotes and pagination can differ
  from the source application. Export to PDF from that app when exact layout
  matters. PowerPoint, spreadsheets and Pages files currently require that PDF
  step. Markdown printouts support the same inline Markdown as note boxes.
- **Printer menu** or **File > Export Page/Section as PDF** exports the current
  page or its section in section order, including subpages. **Command-P** prints
  the current page; File/Printer > Print Section prints the section. Choose A4
  or US Letter in the printer toolbar menu. Pages fit the printable width and
  continue vertically onto additional sheets. Text remains selectable and PDF
  printouts remain vector content; headers, tables, images, highlights and ink
  are rendered without editor controls. A long table/printout can span sheets.
  PDF preparation is cancellable. Exports capture the current page snapshots.

Printout limits: 50 MB input, 200 imported sheets and 200 MB generated media.
Export limits: 500 printed sheets and 200 MB of intermediate PDF data. PDFs must
be readable and unlocked. An attachment remains an attachment unless explicitly
inserted as a printout. Existing ink now renders above images so it can annotate
PDF pages. PDF form/annotation appearance should be compared with the original;
interactive forms, links and document navigation are not notebook controls.

### Install a normal Mac app and Desktop shortcut

Quit Kiyobumi, then build/install using the included command file:

```sh
cd ~/Downloads/Kiyobumi-0.3
./Install-Kiyobumi.command
```

It builds the app, installs it in `~/Applications/Kiyobumi.app`, creates a Desktop
alias named Kiyobumi if that name is free, and launches the installed copy.
The supplied globe/wave artwork is bundled as a Retina application icon and
registered for notebook packages. For an existing build, run
`./scripts/install-macos.sh --desktop`. No administrator password is required.
An update verifies both app bundles and restores the prior app if the final
move fails. Notebooks and preferences remain in their existing locations.
If macOS requests Finder automation access, it is used only to make the alias;
denying it still leaves the app installed. To pin it to the Dock, right-click
the running icon and choose Options > Keep in Dock. The installed copy runs
independently of the Downloads/source folder.


## 0.3.6 launch compatibility fix

The startup scene helper no longer uses if/else inside SceneBuilder, which
caused the reported Swift compilation error in 0.3.5. Explicit returns use
Apple's public buildLimitedAvailability/buildOptional functions to keep the
same opaque scene type on both macOS paths. Swift 5.9 builds retain the original
scene directly. The startup setting and 0.3.5 interface changes are retained.


## 0.3.5 startup notebook and quieter header retained

- Open **Kiyobumi > Settings** (Command-comma), then Choose under Startup
  notebook. Select an existing saved `.onbook` notebook. Future launches open
  it automatically; Change selects another notebook and Clear removes the
  preference. Open now opens the selection immediately. These choices do not
  close your current notebook or delete notebook files.
- Opening a notebook from Finder or File > Open continues to work. Hold Option
  while launching to bypass the default once. An unavailable notebook produces
  a short, dismissible message; change or clear its selection in Settings.
- The toolbar edge blur has been removed. Controls still scroll in narrow
  windows and the Save button remains pinned.
- An empty subheader is simply blank. Click the area below the gray header line
  to type. Return, Escape, a page-body click, or a toolbar click ends editing,
  leaving plain text (or a blank area) with no caret. Subheader edits still
  update the document as you type and use the existing autosave behavior.

The startup preference is stored separately from your notebooks. The native
document reader/writer and notebook schema are unchanged. Modern SwiftUI launch
suppression is used on macOS 15+ with Apple's Swift 6 toolchain; earlier systems
use the AppKit launch delegate. Both paths need the Mac acceptance checks in
`docs/VALIDATION.md`.


## 0.3.4 page interactions and icon retained

- Pinch the trackpad over the page to zoom smoothly, including from Fit width.
  Zoom ranges from 10% to 400%; two-finger scrolling continues to scroll.
  Zoom changes display scale, not saved font sizes or element geometry.
- Click the blank subheader area beneath the header's gray line to enter optional text.
  Clear the field to remove it. Subheaders autosave, participate in search and
  copy with duplicated pages. Their metadata is stored separately so the page
  format stays schema 3 and older Kiyobumi clients preserve it.
- New page and Subpage buttons sit together below the page list. Select a page,
  then choose Subpage to append an indented child after its existing descendants.
  The existing two-level nesting limit is retained.
- Formatting an entire box outside editing no longer starts text editing.
  Finishing editing clears the native text selection, preventing a stale gray
  highlight. Range selections remain available while actively editing.
- The app bundle gets the user-selected globe/wave icon with all lettering
  removed. macOS builds generate its Retina icon sizes with sips/iconutil.
  The edited artwork and provenance are in macOS/Assets and docs/BRANDING.md.


## 0.3.3 section tabs and preselected text style retained

- Colored binder tabs sit beneath the toolbar and above the page canvas.
  Clicking one selects the same section as the sidebar and updates the page
  list. The selected tab is highlighted and scrolled into view. Long names
  truncate with their full name in a tooltip; the All sections arrow lists
  every section when the tab row overflows.
- The plus button creates a section. Right-click a tab to rename it, change
  its color, move it left/right or delete it. New sections choose an unused
  preset color when available. Existing/imported colors are retained; color
  and order are saved in the existing notebook format. Colors can also be
  changed from the sidebar's section context menu.
- Choose Text, then pick font family/size, bold/italic/underline or color before
  clicking to create a box. The next box uses that style. Inserted checklists
  also inherit the chosen style. If an existing box is selected, formatting
  applies to it; choosing Text first prepares a new box without changing it.
  The pending style belongs to the current page editor and is not a global
  preference. List operations still need an existing text box.
- Tabs remain available in an empty section so another section can be chosen.
  Clicking a tab clears an active search to show that section's pages.


## 0.3.2 toolbar update retained

- Cursor tools use compact, equal-size buttons with a selected-tool highlight.
  Their group sits six points from the font/ink group, without a wide separator.
- Font/ink, insert/paper, history and zoom controls sit in bordered groups.
  Individual controls have more spacing and larger clickable areas. The
  60-point toolbar height and larger icons are retained.
- The pinned floppy-disk button saves immediately. Its small status badge
  shows a check when saved, a clock when awaiting a first save/pending/saving,
  and a warning after a save error. The check describes saved state; it is
  not an autosave on/off switch. The adjacent arrow opens status/options.
- The floppy is original vector artwork, scales cleanly and adds no image
  dependency. Converter, notebook format and autosave behavior are unchanged.


## 0.3.1 fixes retained

- Valid standalone revision reference-count records are accepted. The supplied
  Boilers and Combustion file now converts nine pages with 2,932 ink strokes.
- OneNote ink deltas are reconstructed before scaling, fixing the long spokes
  created by reading each movement as an absolute position. Reimport affected
  sections to get corrected ink; already-saved converted strokes are unchanged.
- Import errors use a fixed-size sheet with a short explanation, scrollable
  technical details, Copy details, and an always-visible Close button. Escape
  or Return dismisses it. Huge reader dumps cannot push the button off-screen.
- Toolbar controls return to regular size, with larger icons/font controls and
  a 60-point row. Save status remains pinned at the right.
- Windows start around 1400 × 900 logical points, clamped to the usable screen.
  Compact frames restored from the old app are enlarged once; later manual
  resizing is respected.
- The working autosave and text editing behavior is retained. Schema remains 3.

This archive unpacks into Kiyobumi-0.3 to reuse the existing build cache.
The parser now has a documented MPL-2.0 compatibility patch; corresponding
modified source is supplied and bundled. See third_party/README.md.


## What's changed

- One native TextKit editor now handles display, editing and measuring text.
  Each text change reaches the document binding synchronously; the full string
  is saved independently of the box height. Long text, wrapping, larger fonts
  and trailing newlines use the same measured layout after reopening.
- Click outside a text box in the page area to finish editing. Escape also
  remains available. Editing boxes are transparent.
- One aligned toolbar row contains bordered groups for tools, fonts, formatting,
  lists, insert, paper, undo/redo, zoom and import. Controls scroll horizontally
  in narrow windows; the floppy-disk Save button stays pinned at the right.
- Font family and size, bold, italic, underline and text color are available.
  Select characters to format a range; with a caret, format subsequent typing.
  Formatting a selected box outside editing applies to the whole box.
- Bullet, numbered, checkbox, checked-box, checkmark and cross lists are supported.
  Return continues the marker/number; Return on an empty list item ends the list.
  Click a checkbox glyph while outside text editing to toggle it.
- The editable page title/date/time header remains linked to the page list.
  The repeated bold toolbar title and bottom autosave bar are removed.
- OneNote body text imports into portable styled runs. Available font names,
  half-point sizes, bold/italic/underline, text colors and safe hyperlinks are
  retained. Missing Mac fonts use a fallback while preserving the source name.
- Decoded OneNote ink imports as vector strokes, including inline ink outside
  tables. Pressure, pen-tip shape and exact nested/inline placement remain
  approximations; compare with the source.

These changes address the reported clipping and delayed editing issues.
A Mac rebuild and close/reopen test are still required: this development
environment cannot compile against Apple's SDK or exercise native window closing.

