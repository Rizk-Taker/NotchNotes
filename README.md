# NotchNotes

A native macOS editor that lives in your MacBook's notch. Hover over the notch, press Enter, start writing.

[notchnotes.org](https://notchnotes.org) · [Download](https://github.com/Rizk-Taker/NotchNotes/releases)

## Features

**Notch-triggered** — Move your cursor to the MacBook notch and press Enter. A note window appears instantly, focused and ready.

**Split panes** — Split vertically (`⌘D`) or horizontally (`⇧⌘D`). Nest splits, drag dividers to resize, navigate with `⌘⌥Arrow`.

**Built-in terminal** — Full shell alongside your notes. Open a terminal pane with `⌘T` or `⇧⌘T`. xterm-256color, your environment, your shell.

**Window docking** — Drag a window onto another to merge them iTerm2-style. Directional drop zones show where the pane will land.

**Auto-save** — Notes save as you type. Smart filenames from your first line. Markdown or plain text.

**Everything local** — No accounts, no cloud sync. Your notes stay on your machine.

## Keyboard Shortcuts

| Action | Shortcut |
|---|---|
| New note | `⌘N` |
| New terminal (from notch) | `⇧⌘Enter` |
| Split vertical (editor) | `⌘D` |
| Split horizontal (editor) | `⇧⌘D` |
| Split vertical (terminal) | `⌘T` |
| Split horizontal (terminal) | `⇧⌘T` |
| Focus pane | `⌘⌥Arrow` |
| Close pane | `⌘W` |
| Save | `⌘S` |
| Find | `⌘F` |
| Zoom in/out | `⌘+` / `⌘-` |
| Settings | `⌘,` |

## Requirements

- macOS 14.6+
- Apple Silicon or Intel

## Building from Source

1. Clone the repo
2. Open `Notes.xcodeproj` in Xcode
3. Build and run (`⌘R`)

The project uses [SwiftTerm](https://github.com/SwiftTerm/SwiftTerm) for terminal emulation, resolved automatically via Swift Package Manager.

## License

All rights reserved.
