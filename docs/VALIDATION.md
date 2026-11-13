## 0.7.10 validation

The supplied 0.7.9 report crashes in objc_msgSend from _NSUndoStack popAndInvoke. No application frame identifies the recipient. Code inspection found native text editors used window undo without teardown cleanup. This release isolates their histories, clears them on teardown, and invalidates text undo when model snapshots replace native content.

Added macOS regression tests for native typing undo/redo in both editor types, history reset, editor removal, independent manager ownership, and no window-manager sharing. These AppKit tests require macOS and have NOT been run here. All Swift files were syntax-parsed with tree-sitter; Linux cannot compile or execute AppKit. Mac retest required: type/paste, Cmd-Z/Shift-Cmd-Z, delete a box/table, switch pages/notebooks, then Cmd-Z. Check autosaved text after reopening. Existing page snapshot toolbar undo remains independent.

# Kiyobumi 0.7.9 toolbar validation

Swift source/test syntax and Info.plist checks pass. Theme control panels are
lighter than the patterned backgrounds; white text contrast exceeds 7:1 on all
three dark panel colors. Native text/icon/disabled rendering still requires
visual checking on macOS. The native window bar uses SwiftUI toolbarBackground
with windowToolbar placement; its exact rendering under macOS 27 is unverified.

Check toolbar groups, section-tab strip, native title/toolbar area and sidebar
action visibility in all themes and appearance modes. Disabled Undo/Redo may
remain dim until an action is available. Classic uses automatic native styling.
No document, click-handling, import or print logic changed.

# Kiyobumi 0.7.8 sidebar validation

Swift source/test syntax checks and Info.plist parsing pass. Native Mac rendering
is unverified here. Inspect all three themes in light and dark appearance: both
navigation columns should have coordinated backgrounds, text must remain
readable, and selected rows must remain distinguishable. Check notebook search
results and the empty-section state as well. Switching to Classic must restore
native backgrounds. The change affects presentation only; the click handler,
notebook model and import/print code are unchanged.

# Kiyobumi 0.7.7 theme validation

Three original SVG patterns were rasterized and visually inspected side by side.
PNGs are 384 x 320 and use a uniform ground color at their tile boundaries.
All source/test Swift files pass tree-sitter syntax parsing; the build script
passes bash syntax checking. Packaged resources and matching editable SVGs are
verified. Native macOS compilation and live SwiftUI appearance remain untested
on this Linux host; the inspected pattern preview is not an app screenshot.

Manual acceptance: select each theme and Classic; confirm previews, workspace,
toolbar and notebook trim change immediately. Quit/relaunch to verify persistence.
Check all themes in Light/Dark/Follow Mac, narrow-window toolbar scrolling,
section selection, text selection and two-finger box creation. Patterns must not
cover text or intercept mouse events. Paper/ink/PDF output must remain unchanged.
Settings scrolls so all controls remain reachable after adding the gallery.
No changes were made to the native secondary-click handler or Rust importer.

# Kiyobumi 0.7.6 appearance validation

All Swift sources and tests pass tree-sitter syntax parsing; Info.plist parses.
Native macOS compilation and visual validation are not available on this Linux
host. The change uses NSApplication.appearance for all app windows, panels and
popovers. Follow Mac assigns nil, letting AppKit track system appearance.
An ObservableObject stores the selection in a dedicated UserDefaults key;
startup restores the selection before opening the default notebook/library.

Notebook colors, saved data and print/export paths are unchanged. Existing
light canvas environments remain; native text/table editors explicitly use
Aqua to keep carets and selection readable on document paper. This release adds
interface dark mode, not display recoloring of pages. The working native
secondary-click handler is unchanged.

Mac acceptance: switch among all three choices in Settings, check existing and
new windows/dialogs, quit/relaunch to check persistence, and change macOS theme
while Follow Mac is selected. Check typing/caret, table cells and imported ink
on light paper, section tabs in dark chrome, and two-finger box creation.

# Kiyobumi 0.7.5 click-routing validation

All Swift source/test files pass tree-sitter syntax parsing. The diagnostic shell
script passes bash syntax checking. macOS compilation, the two new AppKit tests,
and real trackpad input cannot run in this Linux environment.

The previous event monitor has been replaced by native hitTest/rightMouseDown
routing. Ordinary clicks return nil from the overlay, preserving underlying
editors and drawing gestures. Secondary clicks on allowed paper return the
native target. Ink container bounding rectangles are excluded from occupied-area
checks because they often include large areas of empty paper on imported pages.
An opt-in, non-intercepting event monitor logs routing evidence only when launched
with KIYOBUMI_CLICK_DEBUG=1 (scripts/debug-clicks.sh). No notebook text is logged.

Added AppKit tests exercise converted coordinates in a scaled/offset view,
one creation per down/up pair, occupied-area rejection, and ordinary vs Control
click classification. These tests do not prove full SwiftUI event delivery.
Manual acceptance remains: new and imported pages, scrolling/zooming, context
menus on existing content, normal typing/inking, and page/window switching.
The actual cause on the user's Mac is still unconfirmed pending these checks.

# Kiyobumi 0.7.4 secondary-click validation

All Swift source files pass tree-sitter syntax parsing. Native macOS compilation
and trackpad input validation are not available in this Linux runtime.
The previous implementation listened only for otherMouseDown/button 2. The user
clarified that the desired input is a two-finger trackpad secondary click. The
monitor now also handles rightMouseDown, while leaving occupied element regions
and table controls alone; it consumes the paired release only after creation.
The physical middle button remains supported on blank paper.

Mac acceptance: two-finger click blank paper and type immediately; expect one
box at the pointer. Repeat after scrolling and zooming and with another box
being edited. Secondary-click text, table cells and images must not create a box;
existing context menus should retain their behaviour. Check that a single click
creates only one box and does not show a menu over it. Repeat on a new page and
an imported page. Normal clicks, drawing and two-finger scrolling are unchanged.
No Rust files or corresponding-source archive changed in this update.

# Kiyobumi 0.7.3 middle-click validation

All Swift source files pass tree-sitter syntax parsing. Native macOS
compilation and physical mouse testing are not available in this Linux runtime.
The earlier listener used an unsized background NSView. The repair gives it an
explicit frame and sizeThatFits result, places it above the paper, and ties
monitor registration/removal to window attachment. This is a targeted repair
for a suspected event-region/layout failure, not a reproduced Mac diagnosis.

Mac acceptance: press the physical middle mouse button over blank paper; expect
one text box at the pointer with typing focus. Repeat at 50%, 100% and 200% zoom,
after scrolling, after changing pages/notebooks and after reopening a window.
Header, toolbar, sidebar and sheet clicks must not insert. Normal left/right
clicks and ink must remain usable. Mouse software must deliver middle-button
(button 2) events rather than remapping the button to a system action.
The Rust importer and corresponding-source bundle are unchanged from 0.7.2.

# Kiyobumi 0.7.2 import validation

Rust 1.89.0, Linux: `cargo test -p one-import -p onenote_parser --locked`
passes 72 parser tests, 11 importer unit/integration tests and one doctest;
two existing doctests are ignored. Five parser cases were added for this fix.
The supplied private OneNote section imports eight pages, one embedded image
and 3,188 ink strokes. All emitted ink coordinates are finite; a sample ink
render was inspected. Private input and converted output are excluded from
this release. Source SHA-256:
f02e208c174b3edb42cf4836120da89db6b7b562fdbbbc7648a11da515443500

Native macOS compilation and in-app import/layout validation remain necessary.
No Swift UI code changed in this patch. Check that the formerly failing section
opens, that all eight pages are available and that saved imported notebooks reopen.
This test confirms parsing, not perfect OneNote layout/formatting fidelity.

# Validation of Kiyobumi 0.5.7


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

## 0.5.5 SDK 27 compatibility

The supplied Mac log shows missing SwiftUIMacros.StateMacro, followed by missing
projected bindings and immutable-self errors. All app @State attributes now
resolve through a generic alias to the SwiftUI.State property-wrapper type.
Static checks verify no bare @State attributes remain and unrelated wrappers
are unchanged. Swift syntax and ZIP integrity checked; SDK 27 compilation and
interactive state/binding tests cannot be run on this Linux host. Confirm typing,
selection, sheets and notebook renaming on the Mac after building.

## 0.5.4 system sharing and native renaming

Static Swift syntax, shell syntax, plist and archive integrity checked. No Mac
SDK build, XCTest or UI runtime is available in this environment.

Mac checks required: rename by Return and focus loss, reopen from Finder and the
collection, verify no duplicate old entry, then restart with a renamed startup
notebook. Check duplicate filename, read-only folder, blank/invalid name and an
unsaved notebook. Verify existing name/filename mismatches can be synchronized
with Return. Confirm saving after moving retains recent page edits.
Check title removal after Save As, switching notebooks and resizing. Check the
system Share icon with an active notebook, no notebook, after editing, during a
rename, cancelling the sheet, and AirDrop to another Mac. Sharing waits for its
native save and refuses to race an in-progress rename.

## 0.5.3 alignment and sharing

Swift syntax, plist, shell and ZIP checks performed. No native macOS build or
UI execution is available here. Visual acceptance: check count centring above
the page list at minimum and expanded widths; confirm notebook heading inset;
open a notebook and verify the narrow initial page column. Test sharing after
editing, cancelling the share sheet, a save failure, and an unsaved notebook.
Verify AirDrop on a Mac with a nearby recipient and open the received package.

## 0.5.2 notebook switching

Reviewed the display ordering: open without display, prepare frame, bring forward,
then hide the source. Window animation settings are temporarily disabled and
restored. Native Mac checks remain required: switch to both previously opened
and newly opened notebooks, preserve edits, and test full-screen behaviour.

## 0.5.1 word-count position

The sole application code change is toolbar placement: principal to navigation.
Swift syntax, plist and archive checks passed. Native macOS placement still needs
visual verification, including resizing and toggling the sidebar.

## 0.5.0 notebook collection and writing aids

Added a local notebook catalogue, safe unique-name creation, native-document
switching and close/save guards. The on-disk notebook schema is unchanged.
Word counts use Apple NaturalLanguage tokenization and omit non-text objects;
native text editors enable continuous spell checking once at creation so the
user can still toggle it through standard macOS menus.

Validation here: Swift tree-sitter syntax, shell syntax, bundle plist and ZIP
integrity. No macOS SDK, native build, UI execution or XCTest run is available
in this environment. Added macOS regression tests for word-count extraction
and filename sanitization; these remain unexecuted here.

Mac acceptance checks:
- Create two notebooks with the same name; confirm separate files and switch
  between their pages after typing, then quit/reopen and verify saved text.
- Open an older notebook; change its display name and cover colour. Close it
  from the list, confirm the file remains, and open it again.
- Change the creation folder, create another notebook, then verify its location.
- Try closing with unsaved changes and cancelling any save/error prompt.
- Type in text boxes and table cells: count updates, misspellings underline,
  suggestions work, and spelling can be toggled via the Edit menu.
- Check title/subtitle counting, Markdown links, symbols, Japanese text, and
  switching pages. Count must not include attachment filenames or printouts.
- Check launch, Dock reopen, and notebook switching in full screen.

## 0.4.9 starting width

The shared new-text-box constructor now starts at 160 instead of 320 points.
The only application code change is this width literal. Diff, plist and archive
checks verify the change; native Mac execution is unavailable here. Check a new
box from Insert and from the Text tool, then type beyond its initial width.

## 0.4.8 header spacing and subtitle colour

The single-line-title header is 116 points instead of 144. Shared header sizing
reserves extra title height for a second line and is used for PDF pagination,
body translation and culling. Subtitle display/editing uses secondary foreground;
PDF date/time and subtitle share grey. Stored body coordinates are unchanged.

Swift syntax, shell syntax, plist and archive integrity are checked; no Apple SDK
build or native visual test is available here. On Mac, compare blank/populated
subtitles and one-/two-line titles at different zoom levels. Confirm the subtitle
remains editable, the body starts one ruled line higher for a normal title, ink
stays aligned with objects, and exported PDFs include the final content.

## 0.4.7 horizontal text growth

Content changes measure natural line width through the same attributed TextKit
layout, then grow the box before calculating height. Growth is bounded by the
existing canvas width limit and never shrinks the current width. Display-only
measurement and table cells do not trigger widening. No file format change.

Added a Mac XCTest for growth, reduced soft wrapping, explicit newlines, width
retention after shortening text and larger-font measurement. No Apple SDK build
or XCTest execution is available here; Swift syntax, shell syntax, bundle plist
and archive integrity are checked separately.

Mac acceptance: type past the right edge of a new and an imported text box;
confirm smooth horizontal growth and caret visibility. Paste long lines and
multiple paragraphs, increase font size, press Return, delete text, manually
narrow, undo/redo and save/reopen. Check pen coordinates and table widths are
unchanged. Confirm opening a notebook alone does not widen old text boxes.

## 0.4.6 highlight and pointer interaction

Text highlighting uses a direct toggle plus colour dropdown, with a persisted
last-used colour. CanvasTextView enables editing before passing the original
mouse event to TextKit so the first click can position the caret. Existing
checkbox and link handling is retained. Text/table movement is now routed through
four narrow outline strips; interior dragging no longer moves those objects.
Canvas selection respects the text interior versus border and preserves table
cell focus requests. The Text tool permits interaction with existing text.

Swift syntax and shell syntax checks, bundle metadata and ZIP integrity are
checked. Apple SDK compilation and native pointer/keyboard testing cannot run
here. No native UI result is claimed from syntax parsing.

Mac acceptance: click between characters in an unselected note and type; verify
caret placement on the first click. Drag across text to select without moving
the box. Hover/drag each border at different zoom levels and check movement,
Undo/Redo, Delete and whole-box formatting. Check table editing and column
resizing still work. Test the Text tool on existing text and blank canvas.
Highlight selected text with one click, remove it, select a different colour,
click a different unhighlighted selection and repeat. Relaunch to check colour
memory. Verify checkbox toggles, links, final-character autosave and print output.

## 0.4.5 table arrow navigation

Table-scoped weak cell references route plain arrow commands at text boundaries
to an adjacent native editor in the same window. Selection, modifier shortcuts
and active marked text keep native handling. Up/Down checks layout-manager visual
line fragments, including a trailing blank line, rather than newline counts.
No neighbours means native handling; navigation does not create rows or columns.

A new Mac XCTest covers first/middle/last visual lines, wrapped text, trailing
newlines and empty cells. This test and Apple SDK compilation cannot run here;
Swift syntax, shell syntax, bundle metadata and archive integrity are checked.

Mac acceptance: navigate a 3x3 table of empty cells in all directions; verify
edges stay in the table. Repeat with text, multiline cells, wrapped text, emoji
and a final newline. Check Left/Right move normally inside text and Up/Down within
wrapped paragraphs. Check Shift selection, Option word movement, IME input and
Return. Add/remove rows, click different cells, switch pages and open two notebooks;
focus must never jump to another table/window. Arrow navigation must not edit text.

## 0.4.4 native cell input and resize handles

Replaced submitting table TextFields with plain native NSTextViews; Return is
handled as insertText(newline) and textDidChange writes every edit to the binding.
Clicking a nonediting cell requests editing and focus in that cell after the
canvas selection gesture completes. Existing Markdown preview is preserved when
leaving editing. Native column handles receive mouse/cursor tracking themselves
instead of placing a non-hit-testing cursor view behind SwiftUI gesture layers.
Drag deltas account for canvas scale.

Controls float above the table; editing no longer contributes 36 points to its
height. Canvas click-out detection includes the floating controls. Tables ignore
old explicit minimum heights and omit the vertical corner handle. Shared table
measurement makes print output content-sized too. No file format change.

Added a height regression test for old minimum heights and editing-state size
invariance. Native SDK compilation, cursor interaction and XCTest execution are
not available here. Syntax and packaging checks do not establish Mac behaviour.

Mac acceptance: single-click each cell in a previously unfocused table and type;
press Return and keypad Enter, type more lines, wrap text, delete text, click out,
save/reopen and verify the final characters. Check IME input and paste. Check that
floating +/- controls work without moving cells or changing table height. Open
an older stretched table: it should fit its contents. Resize each column at
50%, 100%, 200% and Fit width; check cursor appearance/exit and that drag distance
matches the pointer. Check cursor after ending editing and changing pages. Print
and export the table; compare row heights with the editor.

## 0.4.3 compact table rows

Removed the 36-point minimum row height and reduced vertical cell padding from
8 to 3 points. Row height follows the tallest cell, including wrapped content
and a trailing empty line. Screen and PDF cell insets share constants. Explicit
minimum table heights are retained. Column drag strips have native AppKit
horizontal resize cursor rectangles without intercepting mouse gestures.

Added a Mac XCTest covering blank/single-line rows, multiline content, an
unaffected neighbour row, wrapping and trailing newline. No Apple SDK build or
XCTest execution is possible here. Swift syntax, shell syntax, plist and ZIP
checks are performed; these do not validate native text layout or cursor events.

Mac acceptance: create a table; confirm compact empty rows. Type three lines in
one cell and verify only its row grows. Wrap text by narrowing a column, delete
text again, save/reopen and compare PDF output. Hover each column border while
editing; confirm the horizontal resize cursor and normal text cursor on leaving.
Check borders at 50%, 100%, 200% zoom and after ending editing or switching pages.

## 0.4.2 image picker and independent columns

Image, Attachment and Document printout share one retained native NSOpenPanel
entry point, replacing the remaining stacked SwiftUI fileImporter modifiers.
Table column drags change only the target width and update the overall table
frame. The last column and single-column tables have a resize divider too.
Adding/removing columns retains the remaining widths. No schema change.

Added an XCTest for unchanged neighbour widths, the minimum width, a single
column and native document round-trip geometry. Native XCTest and Apple SDK
compilation cannot run in this Linux environment. Swift syntax, shell syntax,
bundle metadata and archive integrity are checked separately.

Mac acceptance:
1. Insert Image: cancel/reopen, choose PNG/JPEG, check selection and visibility,
   resize, save/reopen. Check Attachment and Document printout still work.
2. Double-click a table; drag each column's right edge at 50%, 100%, 200% and
   Fit width. Other column widths must remain unchanged, including resizing the
   last column and a single-column table. Text must reflow without clipping.
3. Add/remove columns; existing widths should persist. Finish editing, undo,
   redo, save/reopen and export to PDF; compare widths and final text.

## 0.4.1 printout picker correction

The user clarified that Document printout did not open any chooser. This update
replaces that action's stacked SwiftUI fileImporter with a retained NSOpenPanel,
presented after menu dismissal and attached to the editor's document window.
Its completion starts conversion after the chooser closes; progress uses an
editor overlay rather than a second sheet. The conversion code is unchanged.
The first inserted page is selected and revealed, with an insertion-count notice.
The target page is checked before inserting; changing pages cancels preparation.

All 35 Swift files passed syntax parsing. Shell syntax, bundle plist (0.4.1,
build 12), ZIP integrity and executable script permissions passed checks. Only
PageEditorView, the bundle version and release documentation changed from 0.4.0.
No Apple SDK type check, native picker interaction or scroll positioning test
could run in this Linux environment. This is a source-level fix pending Mac
verification; the exact presentation failure was not reproduced here.

Mac acceptance for this fix:
1. Open Insert (+) > Document printout. Confirm a chooser appears. Cancel and
   reopen it, then choose a small PDF. Confirm visible printout content, selection
   of its first page and the insertion count. Dismiss the notice.
2. Repeat on a long notebook page at 50%, 100%, 200% and Fit width; confirm the
   first imported page is brought into view. Repeat with TXT, RTF and DOCX.
3. Cancel conversion of a large document; no partial printout should appear.
   Import a locked PDF; confirm a short, dismissible error. Retry a valid PDF.
4. Check Image and Attachment choosers still work. With two document windows,
   verify the chooser and inserted content belong to the window that invoked it.
   Save/reopen and confirm the printout persists. Repeat printing/PDF export.

## 0.4.0 checks and Mac acceptance

All 35 Swift source/manifest/test files passed syntax parsing. Build, icon,
installer and command-file shell syntax, bundle plist parsing, JSON Schema
validation and relationships for all three public sample notebooks passed.
The Rust converter/reader sources, lockfile and app icon source are unchanged.
The archive excludes build caches and retains executable script permissions.

Seven new XCTest cases cover v4 metadata round trips and validation, clearing
highlights against a highlighted base format, table width/height reflow, PDF
continuation/section order/final content, PDF printout pages/source preservation,
and long-text printout pagination. The distribution contains 53 XCTest cases.
**None ran in this Linux environment. No Apple SDK type checking, native UI
launch, PDF rendering/visual inspection, Finder installer run or printer test
was possible here.** Source syntax checks are not a Mac build or acceptance test.

On a Mac, run `./scripts/build-macos.sh --test` with full Xcode, then:

1. Select text/table boxes and drag the right edge and corner at 50%, 100% and
   200% zoom, including Fit width. Text must wrap without losing its last line;
   one Undo reverses a completed resize. Resize table columns in editing mode,
   add/remove rows and columns, save/reopen and compare widths/minimum heights.
   Check short and multiline cells, long words, Markdown and imported tables.
2. Select an element and press Delete/forward Delete. Undo restores it. Repeat
   while editing a text box, title, subheader, table cell, sidebar search and a
   different document window: those text fields must only delete characters.
3. Highlight a character range in each color, remove part of a highlight, apply
   to a whole box and choose a highlight before inserting a box. Include emoji
   and kanji. Save/reopen; confirm text and colors. Verify new fields cause v4,
   while unextended notebooks remain v3. Older clients must reject v4 cleanly.
4. Import multipage, rotated and cropped PDFs, a DOCX, an RTF and long TXT file.
   Compare first/last pages and PDF annotation appearances with originals.
   Cancel midway and check no objects were inserted. Try an unreadable/locked
   PDF and check a short, dismissible error. Add ink and text on a printout.
5. Export A4 and Letter PDFs of a page and a section with subpages, long content,
   a wide table, formatted text, highlights, transparent images and printouts.
   Open in Preview: verify section order, page count, header/subheader, final
   content, orientation, ink alignment and text selection. Compare PDF vector
   detail at high zoom. Print a sample using Command-P and File > Print Section;
   cancel a job and cancel preparation. Check the other open notebook is untouched.
6. Quit the app and run Install-Kiyobumi.command. Confirm ~/Applications and
   Desktop alias launch the installed copy, with the icon in Finder and Dock.
   Rebuild/update and verify preferences, startup notebook and saved notes stay.
   Try a declined Finder automation prompt: installation should still succeed.

## Historical 0.3.6 launch helper correction

The user reported an Apple SDK build failure at the if/else availability check
in controlledNotebookLaunch. SceneBuilder supports availability-only optional
scenes but not an else branch. This helper now has no result-builder annotation;
explicit returns use SceneBuilder.buildLimitedAvailability and buildOptional
to produce the same opaque result type from either runtime path. The Swift 5.9
compile-time fallback returns the original scene.

All 29 Swift source/manifest/test files passed syntax parsing. Shell syntax,
bundle version 0.3.6/build 10, ZIP integrity and build-script executable modes
passed checks. Only the launch helper, bundle version and release documentation
changed from 0.3.5. These checks do not type-check against SwiftUI; no Apple SDK
build or native launch test was possible here. Repeat the 0.3.5 Mac acceptance
steps after rebuilding.

API references:
- https://developer.apple.com/documentation/swiftui/scenebuilder/buildoptional(_:)
- https://developer.apple.com/documentation/swiftui/scenebuilder/buildlimitedavailability(_:)

## Historical 0.3.5 checks

All 29 Swift source/manifest/test files passed syntax parsing. Shell syntax and
bundle plist checks passed (0.3.5/build 9). The toolbar overflow material and its geometry preference code
were removed. Empty subheaders now use a plain button-sized text region;
a text field exists only while editing. Header height and body origin remain
unchanged. The notebook model, native document codec/autosave implementation,
Rust source/lockfile and icon artwork are byte-identical to 0.3.4.

Three additional Mac tests cover startup preference persistence and clearing,
rejected replacements retaining the old selection, and unavailable notebooks
retaining the preference for recovery. These tests were not executed here.
There is no Apple SDK or native macOS runtime in this environment; syntax parsing
does not establish a successful Mac build or verify document-launch behavior.

Mac acceptance:
1. Build with scripts/build-macos.sh; run --test if full Xcode is available.
   Open Settings with Command-comma. Choose a saved notebook, quit, then launch
   from Finder/Dock and confirm it opens once. Edit, quit and reopen to confirm
   native autosave still preserves final characters.
2. Change the default, relaunch and confirm the new selection. Clear it and
   confirm the ordinary file chooser returns. Confirm File > New still works.
   Change/Clear must not close a current document or remove any notebook file.
3. Launch by double-clicking a different .onbook notebook. It should open that
   document without the default being opened as a second document. Repeat
   with no app running, app running, and with multiple already-open notebooks.
4. Move the default notebook and relaunch: bookmarks should resolve its new
   location. Remove it or disconnect its drive: the message must be short and
   dismissible; Settings must allow Change/Clear. Hold Option during launch to
   bypass it once. Test reopening from Dock after closing all document windows.
5. Repeat launch checks on macOS 13/14 with Swift 5.9-era tools, and macOS 15+
   with Swift 6 tools. Native window restoration and the older AppKit fallback
   require validation on those systems.
6. An empty subheader must show neither placeholder nor caret. Click its blank
   area, type, then press Return/Escape or click the body/title/toolbar. Only
   active editing shows a caret. Clear all text and leave editing: the area
   must be blank. Switch pages, save/reopen and check text, title and ink origin.
7. Shrink and horizontally scroll the toolbar. No blur/material overlay should
   appear at either edge; every control and pinned Save must remain usable.

## Historical 0.3.4 checks

## 0.3.4 checks

All 26 Swift source/manifest/test files passed syntax parsing. Both build
scripts passed shell syntax checks; the bundle plist references Kiyobumi.icns
and reports version 0.3.4/build 8. The edited source icon is a square 1254-pixel
PNG; its signature, dimensions and every PNG chunk checksum passed. The
generated edit was visually inspected for removal of the supplied lettering.

Notebook model, page JSON codec, schema version, Rust converter/reader and
autosave implementation remain unchanged. Optional subheaders use a separate
ancillary JSON file; its schema is documented and malformed/newer metadata is
not overwritten. Six additional Mac tests cover subheader compatibility,
subpage insertion/depth, magnification policy and native selection cleanup.
The distribution now contains 43 Mac XCTest cases. They were not executed here.
No Apple SDK build, native gesture/material check or iconutil run was possible
in this Linux environment.

Mac acceptance:
1. Pinch in/out over the page, repeat several gestures, interrupt a gesture,
   and begin from Fit width. Check the live zoom percentage and 10–400% bounds.
   Scroll using two fingers and confirm pen/text operations still work.
2. Shrink the window and scroll the toolbar. Check the subtle right-edge glass
   fade only while more controls remain offscreen; clicks/scrolling must pass
   through it and the pinned Save control must stay clear.
3. Add/clear a subheader, save/reopen, search it and duplicate its page. Confirm
   the subtitle copies, the page title/date and body/ink positions stay intact.
   Open/save in an older Kiyobumi client and check the ancillary bytes survive.
4. Select a parent page and create a subpage; check placement after descendants,
   nesting in the page list and the disabled action at level 2.
5. Select a whole text box outside editing and change its font/size. It should
   remain outside editing with no gray text selection. Format selected characters
   during editing, then click outside/Save; the selection highlight must clear
   while the writing, styles and final characters remain intact.
6. Confirm the globe/wave icon appears for the newly rebuilt app in Finder/Dock.

The user reported the 0.3.3 tabs and preselected font controls work perfectly.
This report does not validate the new 0.3.4 native interactions.

## 0.3.3 checks

All 23 Swift source/manifest/test files passed syntax parsing. Bundle metadata
and build-script shell syntax passed. The converter, vendored reader, lockfile,
notebook model and native document reader/writer remain unchanged from 0.3.2.
The source archive excludes private notes and screenshots.

Two additional Mac XCTest cases cover preselected formatting surviving an empty
box save and checklist insertion, and ensuring the previously selected box is
not reformatted when preparing the next one. They require an Apple SDK and
were not executed here. Syntax parsing is not native compilation or UI testing.

Mac acceptance: create several sections, switch tabs/sidebar, rename/recolor and
reorder, then save/reopen and compare colors/order. With many sections/long names,
resize the window, scroll the row and use All sections; switching in the sidebar
should reveal its tab. Test an empty section and selecting a tab during search.
Choose Text, pick a different font and size before creating a box, then type and
save/reopen. Repeat after selecting existing writing; its style must remain
unchanged while the new box/checklist receives the chosen style.

The earlier test notebook supplied for a 0.3.2 opening crash passes structure
and schema checks (34 pages); its native crash cause remains unconfirmed because
no crash report was supplied. The user reported a new notebook opens/closes
normally and prioritized these features. This update does not claim a verified
fix for the earlier crash.

## 0.3.2 checks

This update changes toolbar presentation and adds a direct Save button using
the existing editor-flush/save action. No converter, data model, import reader
or autosave implementation was changed. The user confirmed the import errors
fixed in 0.3.1 no longer occur.

All 22 Swift source/manifest/test files passed syntax parsing. Bundle metadata
and build-script shell syntax were checked. The source ZIP retains the exact
0.3.1 converter, vendored parser and lockfile, including its corresponding-source
ZIP. Syntax checks do not constitute Apple SDK type checking or native UI tests.

On a Mac, verify compact cursor selection/highlighting, spacing/borders in the
font and ink groups, horizontal scrolling at narrow widths and the pinned Save
control. Click the floppy on an untitled document (choose location), then after
typing; reopen and check the final text. The adjacent arrow should show status
and Show in Finder. Check the badge/tooltip for saved, pending and failed saves.
Confirm font formatting preserves the current text selection.

## Import and storage checks completed in 0.3.1

Completed in Linux x86_64 with Rust 1.99.0:

- Release converter/storage build with size optimization/LTO passed.
- All 87 Rust unit/integration tests passed: nine header/C-ABI cases, six
  converter unit cases, five desktop integration cases and 67 reader cases.
  One reader documentation test passed; two remain ignored upstream.
  The two new ink tests cover signed delta accumulation, independent axes,
  scaling, per-stroke reset, incomplete axes and integer overflow.
  Project tests include a real source-ink fixture,
  styled-run ranges, native notebook/CAB equivalence, malformed input, missing
  sections, existing-output refusal and source-byte preservation.
- The release helper passed the embedded-DOCX conversion check. The 14,660-byte
  payload matched the recorded SHA-256; package relationships were valid.
- The release helper converted the private Boilers and Combustion section,
  previously rejected at a standalone revision reference-count record, into
  nine pages and 1,333 elements: 562 styled text boxes, one table, four images
  and 766 ink elements containing 2,932 strokes / 227,340 points.
- The earlier private General section converted four pages and 67 elements:
  51 styled text boxes, five tables, eight images and three ink elements.
  The ink contains three strokes and 266 decoded points.
- Forty-four styled runs retained the requested Calibri name. This checks saved
  metadata, not the availability of that font on a Mac or identical typography.
- All twelve extracted image payloads across the two private sections were
  found intact in their source inputs. Both input SHA-256 hashes stayed unchanged.
  A private plot of General's corrected strokes shows a coherent arrow rather
  than the previous radiating spokes. This is a geometry check, not a complete
  visual comparison with OneNote.
- Both private conversions and all three public examples (schema 1/2/3) passed
  JSON schema validation plus cross-file ID/media/rich-run/ink checks.
- All 21 Swift source/manifest/test files passed syntax parsing.
  Syntax parsing is **not** Apple SDK type checking or a Mac build.
- Build-script shell syntax and bundle plist parsing passed.
- The Linux release import helper was 1,838,864 bytes (about 1.75 MiB).
  This is not the size of the finished macOS application or its ARM executable.

Private source notes and converted contents are excluded from the public ZIP
and public fixtures. Sample conversion checks do not establish visual fidelity.

## Not executed here

The revised Swift application has not been compiled or launched against an
Apple SDK in this environment. None of the Swift XCTest cases ran here.
The distribution contains 18 document tests, five save-policy tests, twelve
rich-text/list/ink tests, four page-interaction tests and four
import-presentation/window-size tests.
These cover bounded diagnostics, screen-fitting window frames,
long Unicode strings and their final
characters, formatting round trips, invalid ranges, synchronous native text
publication, stale height/width measurements, native text layout, font-name
fallback, list continuation/insertion and ink opacity. They require a full
XCTest-capable Mac toolchain.

CI includes a Mac build/test job but has not been run from this workspace.
The user reported that saving and the buttons work in 0.3. Autosave and text
publication were not changed in 0.3.1. That report does not validate the new
window/toolbar/error presentation changes.

## Mac acceptance checks

1. Build and launch Kiyobumi.app with scripts/build-macos.sh. With full Xcode,
   also run scripts/build-macos.sh --test.
2. Open a copy of an existing v1/v2 notebook, edit, save and reopen. Confirm old
   text, tables, images, ancillary files and page creation timestamps remain.
   Schema 3 saves cannot be opened by the older OpenNotebook clients.
3. Type 100+ wrapped lines with a distinctive final line, emoji/kanji and trailing
   newlines. Leave the caret active and immediately close/Command-Q before the
   autosave timer runs. Reopen and compare every character and the visible tail.
   Repeat with two notebooks, mixed sizes, rich paste and Japanese composition.
4. Select a text range and change family/size/bold/italic/underline/color. With
   only a caret, confirm subsequent typing uses that format. Save/reopen and
   confirm styles persist. Try unavailable imported fonts: source names should
   remain saved while a fallback renders.
5. Click outside a text box to finish editing. Confirm the box is transparent
   over ruled/grid paper and that toolbar use preserves the text selection.
6. Apply bullets, numbering, checkboxes, checkmarks and crosses across several
   paragraphs. Return should continue a list and end an empty item. Click a
   checkbox glyph outside editing to toggle it; undo and save/reopen.
7. Shrink the window; test fit width and 25%, 50%, 100%, 200% zoom. Toolbar controls
   use a larger 60-point row and can scroll; save status stays visible. Confirm
   startup is roughly 1400 × 900 points on a large display and fits smaller
   screens. Later manual resizing should stay in place. Resize text boxes
   repeatedly and verify wrapping, height, hit testing and the visible tail.
8. Reimport the user's actual OneNote 2010 exports, especially Boilers and
   Combustion and General; already-converted ink is not rewritten automatically.
   Compare ink scale/position/color and fonts with the source. Verify all pages,
   tables and image bytes; review the report. Pressure/tip shape, nested/inline
   placement, paragraph/table flow, equations and table-cell objects have limits.
   Import malformed input and confirm the error sheet can always be closed
   with its button, Return or Escape, and its details can be scrolled/copied.
9. Run docs/AUTOSAVE.md checks for immediate close/quit, first save, Save As,
   save failure/retry and two separate document windows.
10. Switch macOS application language to Japanese and check the 清文 bundle
    display name. Full interface translation and a custom pictogram are pending.

The sample and published fixtures exercise the version-42 desktop reader.
Complete fidelity for notebooks from the user's OneNote 2010 installation still
requires the on-Mac source comparison above.

## 0.5.8 Mac acceptance checks

- Paste a long rich-text document with headings, paragraph spacing and a final
  marker into a small text box. Scroll to the last line; the white page and box
  must extend below it. Repeat with plain text and with trailing blank lines.
- Type after the paste, undo/redo, resize the box, then close/reopen the notebook.
  Confirm all text and supported character formatting survive and the entire
  block remains reachable. Clipboard paragraph/table layout is normalized.
- Select Yellow from a section tab's colour menu; reopen and verify it persists.
- Native XCTest and visual checks require a Mac; not executed in the Linux
  packaging environment.

## 0.5.9 content flow acceptance

- Stack three text boxes, with a long middle box and a fourth beside them. Type
  and paste into the top box: only overlapping boxes below should move; the
  last line must remain scrollable. Repeat with a growing table cell.
- Delete text: lower boxes must stay in place. Drag boxes manually: no reflow.
- Disable Settings > Editing > Automatically push content down and repeat:
  positions must remain fixed. Re-enable and confirm the preference survives
  restarting. Opening an old notebook alone must not move its contents.
- Finish editing, use the page Undo/Redo buttons, save and reopen; confirm text
  and moved positions restore together. Ink must stay fixed.
- ContentFlowTests covers propagation, storage order, side-by-side notes, width
  growth, shrinking, manual movement, large gaps, ink and repeated measurement.
  Mac XCTest execution remains required (not available in packaging environment).

## 0.6.0 mixed-content acceptance

- Back up a notebook. Put the caret midway through styled text, Insert Table,
  and verify both text halves and formatting survive. Edit a cell with one click,
  add multiline text, resize columns, and add/remove rows via block options.
- Click following text and insert an image, attachment and PDF printout. Cancel
  a picker too. Confirm insertion remains at the chosen location and media can
  be saved back out byte-for-byte. Without an active paragraph, insert standalone.
- Grow the leading paragraph and table, change image size, move the outer box,
  and resize the whole box. Contents must stay ordered without overlap.
- Save/reopen and verify schema 5, formatting, table widths, images, attachments,
  search and word count. Old schema 1–4 notebooks must continue to open.
- Export/print a multi-sheet mixed box. Confirm first/last paragraphs, table text,
  image/printout and attachment filename are present and in the same order.
- Finish editing before page Undo/Redo; confirm inserted blocks and moved boxes
  return together. Test deletion of a block and the entire container.
- Mixed blocks use separate native text editors. Cross-block keyboard merging,
  nested boxes/tables and drag-in conversion of existing standalone items are
  outside this release. Native Mac tests remain unexecuted here.

## 0.6.1 acceptance

- Insert a table into a very wide mixed-content paragraph: the table must keep
  its insertion width. Shrink a column, type more text above, save/reopen, and
  check the column does not expand again. Test a table stretched by 0.6.0 too.
- Open notebook A, switch to B, quit/relaunch: B should open. Switch back to an
  already-open A and repeat. A Settings or file-picker window must not replace
  the remembered notebook. Rename the active notebook and repeat.
- Disable Reopen the last-used notebook, choose A as the specific startup file,
  use B and restart: A should open. Re-enable last-used mode and verify switching
  is tracked again. Test Option-launch, an explicit Finder open, and a missing
  or disconnected notebook drive.
- Regression tests cover independent table width/column shrink and separate
  persisted last-used/pinned bookmarks. Native XCTest and UI checks still need
  a Mac; syntax checks alone do not execute these tests.

## 0.6.2 internal Delete acceptance

- In a mixed box with text/table/text, click the table's outside border and press
  Delete; only the table should disappear. Repeat with Forward Delete and with
  Block options > Select block. Following paragraphs should move upward.
- Click a table cell and type, then press Delete: only characters should be
  removed. Repeat in an ordinary paragraph, title and search field.
- Select an internal block, click another box or a toolbar control, then Delete:
  the former block must not be removed by a stale keyboard selection.
- Remove an image, attachment and final block; the container should remain
  editable. Finish editing and use page Undo/Redo; save/reopen and check contents.
- Regression tests cover preserving surrounding blocks/container identity and
  retaining an editable paragraph. Native keyboard/UI testing requires macOS.


## 0.7.0 table and page design acceptance

No macOS SDK, Swift compiler or GUI is available in the implementation environment. Swift syntax parsing is not type checking. Added PageDesignTests for quoted TSV/padding/limits, schema-6 paper and nested fill round trips, invalid spacing, cell-fill trimming, and template cloning/media deduplication. These XCTest cases must run on macOS with the supported test toolchain.

1. Build with the existing scripts/build-macos.sh. Open an older notebook copy; confirm unchanged editing, internal Delete, column resize, Return and arrow navigation.
2. Right-click a cell while viewing and while typing: change/remove shading. Test standalone and embedded tables. Remove the last row/column after shading it, save, close and reopen. Confirm no invalid cell metadata remains.
3. Copy spreadsheet rows with tabs, quoted multiline cells and quotes; Insert → Table from clipboard. Test insertion inside a paragraph and onto the canvas. Malformed quotes and excessive columns should show a bounded error without inserting content.
4. Change ruling to grid with 19-point spacing, cream paper, and a margin at 64 points. Cancel should leave the page unchanged. Apply then Undo/Redo. Close/reopen and compare PDF/printed colours and spacing, including a second sheet.
5. Save a template containing a subtitle, formatted paragraph, nested table, image and attachment. Create two pages from it; edit one, verify the original/template/other copy are unchanged. Restart and create another. Delete the saved template; existing pages must remain intact. Built-in templates cannot be deleted.
6. Verify exporting a section with different page designs preserves each page's own settings. Old app versions are expected to reject schema 6 rather than drop fields.


## 0.7.1 middle-click acceptance (Mac required)

- With Select, Text, Pen and Highlighter chosen, press the middle mouse button on the page body: exactly one new editable text box at the pointer, using the current font and size.
- Repeat at 50%, 100%, 200%, Fit width, and after scrolling horizontally/vertically. Check placement near all four visible edges.
- Middle-click while editing an existing paragraph/table: existing edits commit, the new standalone box receives typing. Undo removes it; redo restores it; close/reopen retains saved text.
- Header, sidebar, toolbar, clipped/offscreen page areas, inactive notebook windows, modal dialogs and import/print progress must not create boxes. Left/right clicks, wheel scrolling and side buttons must retain their normal actions.
- Switch pages/notebooks repeatedly and close windows: one click must still create only one box (monitors removed on dismantle).

Static Swift syntax and ZIP integrity checks performed here. No native compilation or GUI interaction validation is available in this environment.
