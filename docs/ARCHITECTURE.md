# Architecture

## Overview

Athenaeum is structured as a Swift Package with two executable targets and one shared library:

```
┌──────────────┐     ┌──────────────┐
│  Athenaeum   │     │    Octavo    │
│  (library)   │     │   (reader)   │
└──────┬───────┘     └──────┬───────┘
       │                    │
       └────────┬───────────┘
                │
       ┌────────▼────────┐
       │    Ligature      │
       │ (shared library) │
       └─────────────────┘
```

Both apps depend on **Ligature**, which contains all EPUB parsing logic and reader UI components.

## Ligature

### Models

**`EPUBBook`** — The core model representing a parsed EPUB file.
- `title`, `author`, `language` — Book metadata
- `spine: [SpineItem]` — Ordered list of content documents (chapters) as defined by the EPUB spine
- `tableOfContents: [TOCEntry]` — Hierarchical table of contents with nested children
- `baseURL: URL` — Path to the extracted EPUB content on disk

**`EPUBMetadata`** — Extended metadata parsed from the OPF file, including publisher, description, identifier, and EPUB version (2.0 or 3.0).

### Parsing Pipeline

EPUB files are ZIP archives with a defined structure. The parsing pipeline processes them in stages:

```
.epub file
    │
    ▼
EPUBParser.extractEPUB()     Unzips to a temp directory using /usr/bin/unzip
    │
    ▼
ContainerXMLParser            Parses META-INF/container.xml to locate the OPF file
    │
    ▼
OPFParser                     Parses the OPF file to extract:
    │                          - Metadata (title, author, language, version)
    │                          - Manifest (all files in the EPUB)
    │                          - Spine (reading order)
    │                          - TOC file reference
    │
    ▼
TOCParser                     Parses the table of contents:
    ├─ EPUB2TOCParser          NCX format (navPoint elements)
    └─ EPUB3TOCParser          Navigation document (nav > ol > li > a)
                               Falls back to NCX if EPUB3 nav yields no entries
```

All XML parsing uses Foundation's `XMLParser` (SAX-style). No third-party XML libraries are used.

### Views

**`ReaderView`** — Main reader layout. Composes all sub-views:
- Progress bar at the top
- Collapsible TOC sidebar (left)
- Content area with auto-hiding toolbar and navigation bar overlays

**`ReaderToolbarView`** — Top toolbar (auto-hides). Controls:
- Sidebar toggle
- Book title display
- Font family selector
- Page zoom controls
- Dark/light theme toggle

**`ReaderNavigationBar`** — Bottom navigation (auto-hides). Controls:
- Previous/next chapter buttons
- Direct chapter number input

**`EPUBWebView`** — `NSViewRepresentable` wrapper around `WKWebView`. Renders EPUB chapter HTML with local file access enabled. Handles:
- Navigation delegate for internal link interception
- Page zoom application on load

**`ReaderViewModel`** — `ObservableObject` managing reader state:
- Current chapter index and navigation
- Font family and page zoom level
- Dark/light mode theme
- CSS injection via `evaluateJavaScript` for styling
- Scroll position save/restore across chapters

### Styling

Chapter content is styled by injecting a `<style>` element into the loaded HTML via JavaScript. The injected CSS:
- Sets font family on `body` and forces inheritance on all elements with `* { font-family: inherit !important }`
- Applies background/text/link colors for theming
- Constrains content width to `45em` for readability
- Overrides inline styles from EPUB content using `!important`

Page zoom is handled separately via `WKWebView.pageZoom`, which uniformly scales all content.

## Apps

### Octavo (Reader)

Entry point: `OctavoApp.swift`

Presents a landing screen with a file picker button and drag-and-drop support. When an EPUB file is opened, it uses `EPUBParser` to parse the file and presents `ReaderView` from Ligature.

### Athenaeum (Library)

Entry point: `AthenaeumApp.swift`

Personal book catalog. Import, browse, search, and manage EPUB books. Opens books in the reader via `NotificationCenter`. Uses SQLite for persistent storage — see [DATABASE.md](DATABASE.md) for schema and storage details, and [LIBRARY.md](LIBRARY.md) for the full feature guide.
