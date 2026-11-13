# Watt’s Inside

Your battery percentage. Inside the battery.

## Identity

A small Mac utility with one clear purpose. The name is friendly; the presentation stays quiet. Write **Watt’s Inside** with the apostrophe and capital I. Use `watts-inside` for repository and file names.

The app mark is a green battery with white “85” numerals on a pale silver macOS tile. The number explains the product at a glance; it is a fixed brand illustration, not a live charge reading. The actual menu-bar icon remains a monochrome template with the real percentage.

## Color and type

- Emerald: `#20A65A`, the primary brand accent. Artwork uses subtle tonal variation.
- Porcelain: `#F5F5F7`, for light backgrounds.
- Graphite: `#1D1D1F`, for type.
- White: `#FFFFFF`, for the number inside the green mark.

Use the system sans serif for interfaces and supporting copy. Use rounded bold numerals inside battery marks. Keep headlines short and sentence case. Avoid battery-life, charging-speed, or energy-saving promises that the app does not measure.

## Assets

- [App icon, PNG](../Assets/AppIcon.png): master raster artwork with transparent outer padding.
- [App icon, ICNS](../Assets/AppIcon.icns): bundled native macOS icon, 16–1024 pixel representations.
- [Compiled icon catalog](../Assets/Assets.car): prevents Tahoe from adding a second backing tile.
- [README banner](images/readme-banner.png): wide GitHub artwork.
- [Actual menu screenshot](images/battery-menu.png): product evidence; do not substitute illustrated UI.

Keep the icon front-facing, preserve its proportions and outer padding, and do not add a second tile behind it. The approved menu-bar rendering and optical spacing are separate from the app icon and should not be changed to match the marketing artwork.

The identity does not use Apple logos or imply Apple authorship. The artwork was created with image generation for this project.

## Rebuilding

Run `./scripts/build-icons.sh` with full Xcode installed to regenerate ICNS and Assets.car from the master PNG, then `./build.sh`. Normal app builds use the committed compiled assets and still require only Command Line Tools. The catalog has no runtime dependency.
