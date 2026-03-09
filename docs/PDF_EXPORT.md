# PDF Export

## What It Is

The PDF export feature converts EPUB books into PDF documents using a headless WKWebView renderer. It renders each chapter's HTML through WebKit, captures the output as PDF pages, and merges them into a single document with a table-of-contents outline and metadata (title, author).

Key capabilities:
- Chapter-by-chapter rendering with progress tracking
- TOC outline mapped to PDF page destinations
- Print-optimized CSS injection (typography, margins, page breaks)
- Cancellation support at any point during export
- Caching: the generated PDF is saved beside the EPUB file and reused on subsequent exports

## How It Works

### Components

| Component | Module | Role |
|-----------|--------|------|
| `PDFExportService` | Forma | Rendering engine — manages the off-screen WKWebView, renders chapters, builds outline |
| `ExportJobManager` | Athenaeum | Job orchestration — creates jobs, tracks status, manages save panel and caching |
| `ExportJobsButton` | Athenaeum | Toolbar UI — shows active/completed jobs in a popover with progress bars |

### Data Flow

```
User right-clicks book → "Export as PDF"
    ↓
LibraryView (context menu)
    ↓
LibraryViewModel.exportBookAsPDF(_:)
    ↓
ExportJobManager.startExport(entry:fontFamily:)
    ├── Checks for cached PDF beside EPUB → if found, shows save panel and copies it
    ├── Shows NSSavePanel for destination
    ├── Parses EPUB via EPUBParser
    └── Creates PDFExportService and starts rendering
        ↓
    PDFExportService.exportToPDF(book:fontFamily:progress:completion:)
        ↓
    Returns PDFDocument → saved to destination + cached beside EPUB
```

### The Hidden WKWebView Technique

Since there is no headless HTML-to-PDF API on macOS, the export uses a real `WKWebView` placed in a borderless `NSWindow` positioned off-screen at `(-10000, -10000)`. The window is US Letter sized (612×792 points). This allows WebKit to fully render chapter HTML — styles, images, fonts — before capturing PDF output via `WKWebView.createPDF()`.

### Rendering Pipeline

1. **Setup** — Create off-screen NSWindow + WKWebView with `allowFileAccessFromFileURLs` enabled
2. **Chapter loop** (recursive, one chapter at a time):
   - Load chapter HTML via `loadFileURL(_:allowingReadAccessTo:)`
   - Wait for `WKNavigationDelegate.didFinish`
   - Inject print CSS (font family, margins, page-break rules, black-on-white colors)
   - Wait 0.3 seconds for layout to settle
   - Call `createPDF()` to capture rendered content
   - Extract pages from the chapter PDF and append to cumulative `PDFDocument`
   - Report progress (`current/total` chapters)
   - Failed chapters are skipped rather than aborting the entire export
3. **Build outline** — Map TOC entries to page indices using the `hrefPageMap` built during rendering
4. **Set metadata** — Apply title and author as PDF document attributes
5. **Teardown** — Stop loading, nil out delegates, close window

### Caching

When an export completes, the PDF is saved both to the user-chosen destination and beside the original EPUB file (same name, `.pdf` extension). On subsequent exports, `ExportJobManager` detects the cached PDF and skips rendering entirely — it just shows a save panel and copies the cached file.

### Job Status Lifecycle

```
pending → exporting(current, total) → saving → completed
                                              → failed(message)
       → cancelled (at any point)
```

## How to Use It

### As a User

1. Right-click a book in the library grid or table
2. Select **Export as PDF**
3. Choose a save location in the file dialog
4. Monitor progress via the toolbar button (appears when jobs exist, shows a blue dot while active)
5. Click the toolbar button to see the jobs popover with per-chapter progress bars
6. Cancel an active export or clear completed/failed jobs from the popover

### Programmatically

```swift
// Start an export (shows save panel, then renders in background)
exportJobManager.startExport(entry: bookEntry, fontFamily: "Georgia")

// Cancel a running job
exportJobManager.cancelJob(id: jobId)

// Clean up finished jobs
exportJobManager.clearCompleted()
```

## How to Maintain It

### Key Files

| File | Responsibility |
|------|----------------|
| `Forma/Sources/Forma/Export/PDFExportService.swift` | WKWebView rendering engine, CSS injection, outline builder |
| `Athenaeum/Export/ExportJobManager.swift` | Job lifecycle, EPUB parsing, caching, save panel |
| `Athenaeum/Views/ExportJobsButton.swift` | Toolbar button, jobs popover, progress UI |
| `Athenaeum/Views/LibraryViewModel.swift` | `exportBookAsPDF(_:)` entry point (line ~354) |

### Customizing Print CSS

The `injectPrintCSS(webView:isFirstChapter:completion:)` method in `PDFExportService` controls PDF styling. Key rules:
- Font family is passed through from user settings
- Colors forced to black text on white background
- Images constrained to page width with `page-break-inside: avoid`
- Headings prevent page breaks after them
- Paragraphs use `orphans: 3; widows: 3` to avoid stranded lines
- Non-first chapters start with `break-before: page`

### Known Constraints

- **Sequential rendering**: Chapters are rendered one at a time on the main thread since WKWebView requires main-thread access. This means export time scales linearly with chapter count.
- **0.3-second delay per chapter**: A fixed delay after CSS injection gives WebKit time to reflow. This is a conservative value; reducing it may cause incomplete renders for complex layouts.
- **EPUB-only**: The export guard (`entry.book.format == .epub`) means only EPUB books can be exported. Supporting other formats would require a different rendering path.
- **Cache invalidation**: The cached PDF is never automatically invalidated. If the EPUB file changes, the stale cache will be served. Deleting the `.pdf` file beside the EPUB forces a fresh render.
