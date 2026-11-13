# OneNote 2010 feature checklist

Reference: Microsoft's original October 2010 product guide, rather than a current
Microsoft 365 feature list. Download listing:
https://www.microsoft.com/en-ie/download/details.aspx?id=5829
Guide:
https://download.microsoft.com/download/2/6/2/26253C22-D8EC-4230-A3ED-E2DEED9E8EBE/Microsoft%20OneNote%202010%20Product%20Guide_Final.pdf

This is an implementation checklist, not a promise of compatibility or a copy
of Microsoft's UI. Guide page numbers below are its printed numbers.

| Capability in the 2010 guide | Guide pages | Kiyobumi 0.3 |
|---|---|---|
| Spatial typed notes and pasted pictures | 2–3, 27 | Positioned native rich-text boxes, font/size/color controls, image insertion/import |
| Handwritten input and highlighting | 2, 27 | Mouse/trackpad strokes; decoded source vectors imported with fidelity limits |
| Labels and completion markers | 3, 29 | Bullet/number/checkbox/checkmark/cross lists; imported tag labels |
| Grids of text cells | 24, 28 | Editable rectangular tables; imported text cells |
| More flexible navigation/subpage organization | 14–16 | Subpage indentation, reorder, duplicate, rename |
| Search across note content | 16–17 | Current notebook text search; image/audio search pending |
| Related-note links | 18–19 | Web links; native wiki links pending |
| Version recovery and deleted-item recovery | 10–11 | Pending; page-action undo is session-only |
| Writing alongside a source document | 20–21 | Pending |
| Page decoration and reusable layouts | 27, FAQ | Ruled/grid backgrounds; templates pending |
| File objects and media recordings | 28–29 | File insertion/export/import; recording tools pending |
| Printout insertion, recognition, calculations | 2–3, 27–28 | Image bytes where available; OCR/math tools pending |
| Multi-user notebooks and sharing | 7–13 | Pending; local documents only |
| Office integration, cloud/mobile access | 21–25 | Pending; no dependency on a Microsoft account |

The 2010 guide's discussion of text wrapping in a narrow window also motivates
our fit-width control and a separate page header and a single aligned toolbar row. Full reflow that changes
container geometry to match a window is different from zoom and is not claimed.

## User-requested additions in 0.2.1

Pages now have a title/date/time header linked to their page-list name. The date
and time come from the creation timestamp, including imported timestamps.
Saved notebooks request native autosaves, display save status, and retain the
native close/quit save guard. New notebooks need a first save location. These
are implemented changes; Mac validation is still required (see AUTOSAVE.md).

## Kiyobumi 0.3 additions

Transparent native text boxes publish edits without requiring Escape; clicking
outside finishes editing. Display/editing use the same text layout. Portable
font/style runs and list controls are added, and decoded source ink maps into
native vector strokes. Save status is a compact toolbar icon. Mac close/reopen
and visual-fidelity checks remain required, as detailed in VALIDATION.md.
