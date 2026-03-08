# Athenaeum

A macOS EPUB reader built with Swift and SwiftUI. Zero external dependencies.

![Library](./docs/photos/library.png)
![Reader](./docs/photos/reader.png)

## Apps

- **Octavo** — EPUB reader with support for EPUB 2 and EPUB 3 formats. Open files via file picker or drag-and-drop, navigate chapters, customize fonts and zoom, toggle dark mode.
- **Athenaeum** — Library/catalog app (coming soon).

## Features

- EPUB 2 (NCX) and EPUB 3 (nav) table of contents support
- Chapter-by-chapter navigation with keyboard shortcuts (left/right arrow keys)
- Customizable font family, page zoom, and dark/light theme
- Collapsible table of contents sidebar
- Auto-hiding toolbar and navigation bar for distraction-free reading
- Reading progress indicator
- Scroll position memory across chapters

## Requirements

- macOS 13.0+
- Swift 5.9+

## Build & Run

```sh
swift build            # Build all targets
swift run Octavo       # Run the EPUB reader
swift run Athenaeum    # Run the library app
```

## Project Structure

```
Athenaeum/       # Library app (placeholder)
Octavo/          # EPUB reader app
Ligature/        # Shared library: EPUB parsing and reader UI
docs/            # Documentation
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for detailed architecture documentation.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
