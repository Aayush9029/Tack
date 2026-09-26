# Tack

Glass sticky notes for macOS 26, as a SwiftPM app with no Xcode project.

## Commands

```bash
swift build                      # debug build
swift test                       # TackKit and headless editor tests
./Scripts/compile_and_run.sh     # package Tack.app ad hoc and launch it
TACK_BENCH=1 swift test -c release --filter Benchmarks   # editor and search timings
```

## The `tack` command

`Sources/TackCLI` builds the `tack` command (product `TackCLI`, shipped as `Tack.app/Contents/Helpers/tack`; Settings > General links it into `~/.local/bin`). It reads and writes the app's SQLite database through `NoteStore` and posts `NoteChangeSignal` after every write, so open windows reload (`AppModel.notesChangedOutside`). Unsaved typing in a window wins over an outside change. `TACK_DATABASE=/path/to.db` points the app or the command at another file; use it for tests and never test against the real notes.

Releases are built, signed, notarized and uploaded by `.local/scripts/release.sh`, which is not in git.

## Layout

- `Sources/TackKit`: SQLiteData schema and FTS5 search, Markdown line parser, palette and window models, swipe state machine. No AppKit.
- `Sources/TackUI`: AppKit windows, the TextKit 2 editor, SwiftUI chrome, palette and settings. A library so tests can type into the real editor.
- `Sources/Tack`: `main.swift` only.
- `Sources/TackCLI`: the `tack` command.
- `Resources`: fonts (iA Writer, OFL) and settings illustrations, copied into the bundle by `Scripts/package_app.sh`.
- `Icon/AppIcon.icon`: compiled by `actool` into `Assets.car` at packaging time.

## Decisions that are easy to undo by accident

- Markdown is styled after an edit, as a separate attribute-only change (`MarkdownStyler.restylePending`). Styling inside `processEditing` widens the edited range, and TextKit 2 then moves the insertion point to its end.
- The editor restyles only the edited paragraphs and continues only while the open-code-fence state changes, carried in `.tackEndsInCode`.
- Checkboxes, bullets, code boxes, quote bars, rules and media previews are drawn by `NoteLayoutFragment`; the Markdown characters stay in the text. Task markers use a monospaced font so `[x]` and `[ ]` have one width.
- A change of `textContainerInset` needs a full layout invalidation, or TextKit 2 draws fragments where the old inset put them.
- Note windows are borderless so no system frame or hairline shows; the only window button is a close button drawn in SwiftUI.
- One corner radius (`Metrics.windowRadius`) and one inset make every corner control concentric.
- The palette window is sized from its rows (`PaletteMetrics`), not from SwiftUI's measured height, which clipped the field.
- A plain-text `NSTextView` disables Paste for an image-only clipboard; `validateUserInterfaceItem` turns it back on.
- Resizing, relayout, scrolling and restyling in the editor go through `NoteTextView.setNeedsRefresh`, which runs them after the current event with the selection held. Doing them inside an edit or a layout pass moved the insertion point (reversed typing) and threw inside AppKit layout.
- A heading marker is clamped to the line: a lone `#` used to crash the styler.
- Unpinned notes sit on the desktop layer (`NoteWindowController.desktopLevel`) and are stationary, so no window buries them and Show Desktop shows them; a key note rises to `.floating` and settles back when Tack resigns active. Pinned notes float and are transient, so Mission Control hides them. Tack is an `LSUIElement` app, out of the Dock and ⌘Tab.
- Only one Tack runs (`SingleInstance`); two copies would save over each other's notes.
- The All Notes grid (⇧⌘O, not ⇧⌘↩, which macOS gives to Writing Tools) is a full-screen window over everything; `WaterfallLayout` puts each card in the shortest column.
- Classic is always paper-colored and its window is forced to the light appearance; dark Classic looked like glass.
- Settings' Style, Tint and Appearance change every note (`AppModel.lookChanged`); the title menu changes one.
- A title is inferred with Foundation Models only when the first line is long or a list item (`NoteText.wantsInferredTitle`), after a save, once per change of the note's start.

## Measured (M-series, release, `TACK_BENCH=1`)

- A keystroke: about 1.6 ms (insert 0.8, restyle 0.1, viewport layout 0.7), the same in 200 and 2000 lines. A benchmark window must stay alive: without one the viewport is infinite and every keystroke lays out the whole note.
- Opening a note: 7 ms to style 200 lines, 42 ms for 2000.
- Search over 5000 notes: about 3 ms; parsing: 4 µs a line.
