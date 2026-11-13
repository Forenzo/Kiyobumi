# Kiyobumi / 清文

The project name is **Kiyobumi**. Its Japanese display name is **清文**.
The user's intended meaning is pure/clear/lucid (kiyo) plus writing/script
(fumi → bumi). Use Kiyobumi for the Latin-script application name and 清文
for its Japanese display name.

The application bundle is Kiyobumi.app. macOS/ja.lproj/InfoPlist.strings supplies
the Japanese bundle name. This is display-name localization, not a fully
translated interface. The selected app icon is the user's supplied globe,
colored radial rays and violet-wave artwork, with its lettering removed.

The pre-existing bundle ID, native-format identifier, extension and internal
Swift module are retained so renaming does not create a different document type.
No trademark registration or clearance claim is made.

## Icon artwork (0.3.4)

Source asset: macOS/Assets/KiyobumiIcon.png (1254 × 1254 PNG).
The input was the user-supplied Ultraviolet Spectrum Globe Poster image.
It was edited with the built-in imagegen tool in precise-object-edit mode;
the off-white paper background and the globe/rays/waves were retained.
scripts/build-icon.sh uses the macOS sips/iconutil tools to produce the
standard 16/32/128/256/512-point icon representations at 1× and 2× scales.
Kiyobumi.icns is placed in the app's Resources folder and referenced by the
bundle plist. The source asset is not a Microsoft logo or product artwork.

Final edit prompt:

> Use case: precise-object-edit. Edit target: the supplied square poster.
> Primary request: remove ALL the lower-right lettering, including ELECTRICAL
> TYPING EFFICIENCY and for a modern world. Reconstruct the same off-white subtly
> textured paper where the text was. Change only that typography area. Keep the
> black central globe and white grid, the colored radial rays, the violet wave
> shapes and bright violet lines, their texture, colors, sizes, placement, edges
> and all original composition unchanged. Preserve the square aspect ratio and
> existing opaque paper background. No replacement letters, names, text,
> watermark or added objects. This exact artwork without lettering will be
> used for Kiyobumi's macOS app icon.
