# Retro interface themes

Select Kiyobumi > Settings > Appearance > Theme. Classic restores plain native
chrome. Theme selection is local to the app, persists across launches, and is
independent of the Light/Dark/Follow Mac preference. No notebook data changes.

- Cinema Confetti: midnight blue with mint triangles, pink zigzags, lavender
  loops and small gold shards.
- Deco Triangles: dark teal with layered mint triangles, lilac outlines,
  diamonds, stripes and coral parallelograms.
- Jazz Swirls: purple with broad turquoise ribbons, lilac spirals, peach
  triangles and small geometric accents.

Patterns repeat behind the toolbar and around the page, with a patterned trim
above the notebook sidebar. Toolbar groups retain opaque backgrounds and gain
subtle raised edges. Page paper, text, ink, images and print/export colors stay
as authored. Pattern views never intercept input or enter the accessibility tree.

## Reference research and artwork provenance

Archive reviewed: https://kaleidoscope.hryjksn.com/
The following seven scheme previews were inspected: Confetti, DollyDotsFunky 1.4,
Funky Blues, Memphis `98, M's Triangle 2.1.2, Rainbow Confetti and retro deluxe.
The closest reference directions were Rainbow Confetti (bright geometric trim),
M's Triangle (teal triangular ornament), and retro deluxe (teal/mauve/warm accents).
Memphis `98 was inspected but its largely gray interface was not used as the
main pattern reference.

Reference previews:
https://kaleidoscope.hryjksn.com/images/rainbow-confetti-rainbowconfettisit-b54p.png
https://kaleidoscope.hryjksn.com/images/ms-triangle-212-mstrianglesit-ls1n.png
https://kaleidoscope.hryjksn.com/images/retro-deluxe-retrodeluxesit-me8y.png

These are newly drawn Kiyobumi adaptations of period design ideas, not imported
Kaleidoscope schemes or copies of their bitmap artwork. All shipped SVG geometry
and rendered PNG tiles are original project artwork under this project's MIT
license. Reference screenshots and old .sit files are not included.

## Assets and building

macOS/Themes contains editable SVGs and matching 384 x 320 PNGs, displayed as
192 x 160 point tiles for Retina sharpness. The build script checks and copies
the PNGs into Kiyobumi.app/Contents/Resources/Themes. The app caches these three
small images and tiles them; no image-generation service or web access is used
at runtime. SVG changes can be rendered with CairoSVG at twice their logical size.

## Sidebar palettes (0.7.8)

Both navigation columns use theme-derived solid backgrounds; the page column
is slightly lighter to separate it from the notebooks/sections. Dark and light
appearance have coordinated deep and pastel palettes. Lists hide their native
scroll background only for patterned themes, so the palette remains visible.
Sidebar accent/tint follows the theme; existing section and notebook cover
colors remain intact. Classic restores automatic native list backgrounds.

## Top-bar colors (0.7.9)

Toolbar groups use theme-colored solid panels and bright coordinated outlines.
The section-tab strip uses the secondary sidebar shade. Native window toolbar
background is set through SwiftUI's windowToolbar placement. Dark sidebar action
tints use light mint/lavender for contrast rather than dark selection colors.
