# Saving and page headers in Kiyobumi 0.3.2

The notebook remains a SwiftUI `FileDocument` hosted by `DocumentGroup`.
All edits go through the document binding. All loading and writing still use
`NotebookDocument.read` and `package`; the UI never writes to a file URL itself.
This preserves native file coordination, Save/Save As, and close/quit handling.

For an existing saved notebook, `NotebookAutosave` checks its own window's
`NSDocument` every two seconds. If there are unautosaved changes, it requests
`autosave(withImplicitCancellability:completionHandler:)`. If the host doesn't
support in-place autosaving, it requests a coordinated `save` to the existing
document URL instead. It suppresses overlapping requests from its timer, reports
errors, and waits ten seconds before retrying a failed request. Native document
saving can also occur independently. Successful native saves clear an earlier
error status. Closing/quit uses the native document save guard; no asynchronous
last-minute write is started from `onDisappear` or a window-close notification.

New notebooks need a first save location. The native Save action offers it; the
status does not claim that an untitled notebook is saved. Closing an untitled
notebook presents the native first-save dialog. Choosing Discard there remains
the user's explicit choice. The app does not silently select a hidden notebook
location. If a native document cannot be resolved, the UI says macOS manages
saving rather than claiming the timer has written a file.

Text boxes use a transparent native NSTextView. Its textDidChange delegate
publishes the entire attributed string and its measured height synchronously
to the document binding on every change; quitting does not depend on Escape.
The editor also flushes on focus loss, and the autosave timer flushes active
editors before inspecting document changes. Display/editing/bounds share TextKit
layout. Deferred height measurements cannot publish an old text value.

A pinned floppy-disk button replaces the bottom status bar. Clicking it flushes
editing and requests the native Save action. Its small check badge means saved;
a clock means pending/saving or still needing a first save location, and a warning
means a save error. These badges report state, not an autosave enable switch.
The tooltip and adjacent arrow menu show the current state/error; the menu also
offers Save now and Show in Finder. The control stays visible when the rest of
the toolbar scrolls. Status reflects the native document, not an elapsed timer.

The header displays `Page.title` and `Page.createdAt`. These already exist in
all supported JSON versions. Rich text and ink opacity use schema 3. The title is one binding shared
with the page list/search. A blank title has an Untitled page label in the list.
The date/time uses the user's locale and time zone, retaining the original
timestamp. The header is a separate 144-point band; element and ink coordinates
still refer to the body. Its title wraps up to two lines and remains editable
for longer titles. Drawing and selection gestures attach only to the body.

## Mac acceptance checks

These require an Apple SDK and a running Mac app; they have not been executed
in the Linux development environment.

1. Open a saved notebook, edit a title and body, wait for Saved, close and reopen.
   Confirm both edits and the original creation date/time remain. Use the save
   icon tooltip/menu to inspect status.
2. Edit title/body/table/checklist, then immediately close within two seconds,
   before the timer can run. Leave the caret in the text box: do not press
   Escape or click out first. Reopen and confirm every last character survived.
   Repeat with 100+ wrapped lines, a distinctive final line, emoji/kanji, trailing
   newlines, mixed font sizes, pasted rich text and Japanese IME composition.
   Compare the saved richText.value.text with the displayed text if anything
   looks clipped; the text payload is independent of the element frame.
3. Repeat with Command-Q and with two open notebooks containing different edits.
4. Create an untitled notebook and type notes. Save… must offer a location;
   closing without first saving must offer Save/Cancel/Discard. Cancel must
   keep the notes open. After first save, test steps 1–3 again.
5. Save As to a new location, edit, and reopen the new location. Only the current
   notebook should receive subsequent edits.
6. In a disposable test folder, deny writing, edit, and verify a visible save
   error. Restore writing and save again. Do not choose Discard during this test.
7. At 25%, 50%, 100%, 200%, and fit width, edit a long title, drag a body box,
   draw/erase ink, and change paper. Header/body hit testing must stay aligned.

## Primary API references

- https://developer.apple.com/documentation/swiftui/documentgroup
- https://developer.apple.com/documentation/appkit/nsdocument/autosavesinplace
- https://developer.apple.com/documentation/appkit/nsdocument/autosave(withimplicitcancellability:completionhandler:)
- https://developer.apple.com/documentation/appkit/nsdocument/save(to:oftype:for:completionhandler:)

Apple documents in-place autosaving and native document close/termination
handling. These API guarantees do not substitute for the Mac acceptance checks.

- https://developer.apple.com/documentation/appkit/nstextview/didchangetext()
- https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/TextEditing/TextEditing.html
