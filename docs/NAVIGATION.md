# Navigation

## Overview

The reader uses a centralized chapter navigation system built around a single transition method in `ReaderViewModel`. All navigation — TOC sidebar clicks, arrow keys, page scrolling, bookmarks, overscroll, and the chapter picker — flows through `transitionToChapter(_:scroll:)`, which coordinates state updates, scroll positioning, and async callback invalidation.

## Core Data Model

### Key State

| Property | Type | Purpose |
|----------|------|---------|
| `currentChapterIndex` | `Int` | Index into `book.spine` for the currently loaded chapter |
| `goToChapter` | `Int` | 1-based chapter number, bound to the chapter picker UI |
| `scrollPositions` | `[Int: Double]` | Per-chapter `window.scrollY` values, keyed by spine index |
| `navigationGeneration` | `Int` | Counter incremented on every chapter transition; used to invalidate stale async callbacks |
| `scrollToBottomOnLoad` | `Bool` | Flag consumed by `onChapterLoaded` to scroll to the bottom (used for backward navigation) |
| `pendingFragment` | `String?` | HTML element ID consumed by `onChapterLoaded` to scroll to a fragment anchor |
| `navigationMode` | `NavigationMode` | `.page` (scroll by viewport) or `.chapter` (skip entire chapters). Toggled by double-clicking the mode label in the nav bar |

### ScrollBehavior Enum

Every chapter transition declares an explicit scroll intent:

| Case | Effect | Used By |
|------|--------|---------|
| `.top` | Clears saved scroll position; scrolls to `y=0` | TOC clicks, next chapter, chapter picker |
| `.bottom` | Scrolls to `document.documentElement.scrollHeight` | Backward overscroll, previous page at chapter boundary |
| `.fragment(id)` | Scrolls to `document.getElementById(id)` | TOC entries with `#fragment` anchors, in-document links |
| `.restore` | Keeps existing saved scroll position (or `y=0` if none) | Previous chapter |
| `.position(y)` | Sets an exact scroll position | Bookmark navigation |

## How It Works

### Chapter Transition Flow

All navigation paths call `transitionToChapter(_:scroll:)`. The method executes these steps in order:

```
1. Guard: index is within spine bounds
2. Increment navigationGeneration (invalidates all in-flight async callbacks)
3. saveScrollPosition() for the current chapter (async JS, generation-guarded)
4. collectAndCacheHighlights() for the current chapter
5. Update currentChapterIndex and goToChapter
6. Configure scroll state based on ScrollBehavior:
   - .top / .bottom / .fragment: clear scrollPositions[index]
   - .restore: leave scrollPositions[index] as-is
   - .position: set scrollPositions[index] to the given value
7. loadCurrentChapter() → WKWebView loads the chapter HTML file
```

### Post-Load Scroll (`onChapterLoaded`)

When WKWebView finishes loading the chapter (`webView:didFinish:`), the coordinator calls `onChapterLoaded()`:

```
1. Capture current navigationGeneration
2. Apply theme styles (CSS injection)
3. Inject highlight/note engine (restore highlights from cache)
4. Determine scroll JavaScript based on flags:
   - scrollToBottomOnLoad → scroll to document height
   - initialScrollPosition → scroll to saved app-launch position
   - pendingFragment → scrollIntoView for the fragment element
   - else → scroll to scrollPositions[currentChapterIndex] (default 0)
5. At +0.3s (generation-guarded): execute scroll JS, update page info
6. At +0.5s (generation-guarded): update page info again, start chapter measurement if needed
```

### Page Info and Scroll Tracking (`updatePageInfo`)

`updatePageInfo()` runs a JavaScript function in WKWebView that computes the current page within the chapter and captures `scrollY`. The async callback is guarded by `navigationGeneration` — if a chapter transition occurred between the JS call and the callback, the result is discarded entirely. This prevents stale scroll positions from one chapter being written under a different chapter's key.

### Overscroll Detection (JavaScript)

The `scrollEngineJS` script listens for `wheel` events in the WKWebView. When the user scrolls past the top or bottom of the document by a cumulative threshold (150px), it posts a `scrollHandler` message to Swift. `handleScrollBoundary(_:)` then calls `transitionToChapter` with `.top` (forward) or `.bottom` (backward).

## Navigation Entry Points

All public methods that trigger chapter changes, and how they map to the central method:

| Method | Trigger | ScrollBehavior |
|--------|---------|---------------|
| `navigateTo(href:)` | TOC sidebar click, in-document link | `.top` or `.fragment(id)` |
| `nextChapter()` | Forward arrow key (chapter mode) | `.top` |
| `previousChapter()` | Backward arrow key (chapter mode) | `.restore` |
| `navigateToChapter()` | Chapter picker stepper | `.top` |
| `navigateToBookmark(_:)` | Bookmark popover selection | `.position(y)` |
| `handleScrollBoundary(_:)` | Overscroll wheel events | `.top` (next) or `.bottom` (previous) |
| `nextPage()` | Forward arrow key (page mode), at bottom | `.top` (via `nextChapter()`) |
| `previousPage()` | Backward arrow key (page mode), at top | `.bottom` |

`navigateForward()` and `navigateBackward()` are thin dispatchers that call the appropriate method based on `navigationMode`.

## Async Safety: The Generation Counter

Chapter navigation involves multiple async operations (JavaScript evaluation in WKWebView, delayed scroll positioning). Without protection, a callback from a previous chapter can fire after a new chapter has loaded, corrupting state.

The `navigationGeneration` counter solves this:

1. `transitionToChapter` increments the counter before any async work begins
2. Every async callback captures the generation at call time and checks it before writing state
3. If the generation has changed (meaning another navigation occurred), the callback is silently dropped

This pattern is applied to:
- `saveScrollPosition()` — prevents writing the old chapter's scroll position under the new chapter's key
- `updatePageInfo()` — prevents stale scroll/page data from overwriting current chapter state
- `onChapterLoaded()` delayed blocks — prevents scroll and page-info updates if the user navigated away before the delays fired

## Relevant Files

| File | Role |
|------|------|
| `Forma/Sources/Forma/Views/ReaderViewModel.swift` | All navigation logic: `transitionToChapter`, scroll management, page counting, overscroll |
| `Forma/Sources/Forma/Views/EPUBWebView.swift` | WKWebView wrapper; coordinator calls `onChapterLoaded()` on `didFinish`, routes `scrollHandler` messages to `handleScrollBoundary` |
| `Forma/Sources/Forma/Views/ReaderView.swift` | `TOCSidebarView` calls `navigateTo(href:)`; keyboard handlers call `navigateForward()`/`navigateBackward()` |
| `Ligature/Sources/Ligature/Models/EPUBBook.swift` | `SpineItem` (chapter href, id) and `TOCEntry` (title, href, children) models |

## Maintenance Guide

### Adding a new navigation trigger

1. Determine the appropriate `ScrollBehavior` for the new trigger
2. Call `transitionToChapter(index, scroll: behavior)` — do **not** manually update `currentChapterIndex`, `goToChapter`, or call `loadCurrentChapter()` directly
3. If the trigger fires from an async callback (e.g., JavaScript evaluation), ensure the callback itself is still valid before calling `transitionToChapter`

### Adding new async operations during navigation

If you add a new `evaluateJavaScript` call or delayed block that reads or writes navigation state (`scrollPositions`, `currentChapterIndex`, `chapterPageCounts`):

1. Capture `navigationGeneration` before the async call
2. In the callback, `guard self.navigationGeneration == generation` before proceeding
3. If the callback writes to `scrollPositions`, also capture `currentChapterIndex` before the async call and use the captured value

### Common pitfalls

- **Never read `currentChapterIndex` inside an async callback** — it may have changed. Always capture it beforehand.
- **Never set `scrollToBottomOnLoad`, `pendingFragment`, or `scrollPositions[index]`** outside of `transitionToChapter` — the centralized method ensures these flags are reset correctly for each transition.
- **Never call `loadCurrentChapter()` directly** — always go through `transitionToChapter` so that the generation counter is incremented and state is properly saved/configured.
