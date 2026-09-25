# Tack

Glass sticky notes for macOS 26, as a SwiftPM app with no Xcode project.

## Commands

```bash
swift build                      # debug build
swift test                       # TackKit tests
./Scripts/compile_and_run.sh     # package Tack.app ad hoc and launch it
```

Releases are built, signed, notarized and uploaded by `.local/scripts/release.sh`, which is not in git.

## Layout

- `Sources/TackKit`: SQLiteData schema and FTS5 search, Markdown line parser, palette and window models, swipe state machine. No AppKit.
- `Sources/Tack`: AppKit windows, the TextKit 2 editor, SwiftUI chrome, palette and settings.
- `Resources`: fonts (iA Writer, OFL) and settings illustrations, copied into the bundle by `Scripts/package_app.sh`.
- `Icon/AppIcon.icon`: compiled by `actool` into `Assets.car` at packaging time.

## Decisions that are easy to undo by accident

- Markdown is styled after an edit, as a separate attribute-only change (`MarkdownStyler.restylePending`). Styling inside `processEditing` widens the edited range, and TextKit 2 then moves the insertion point to its end.
- The editor restyles only the edited paragraphs and continues only while the open-code-fence state changes, carried in `.tackEndsInCode`.
- Checkboxes, bullets, code boxes, quote bars, rules and media previews are drawn by `NoteLayoutFragment`; the Markdown characters stay in the text. Task markers use a monospaced font so `[x]` and `[ ]` have one width.
- A change of `textContainerInset` needs a full layout invalidation, or TextKit 2 draws fragments where the old inset put them.
- Note windows are borderless so no system frame or hairline shows; the traffic lights are drawn in SwiftUI and green is focus mode.
- One corner radius (`Metrics.windowRadius`) and one inset make every corner control concentric.
- The palette window is sized from its rows (`PaletteMetrics`), not from SwiftUI's measured height, which clipped the field.
- A plain-text `NSTextView` disables Paste for an image-only clipboard; `validateUserInterfaceItem` turns it back on.
