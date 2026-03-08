# Fonts

## Overview

The reader supports two font modes: a single unified font applied to all text, or a curated font pairing that uses separate fonts for headings and body text.

## Available Fonts

Eight system fonts are available, defined in `ReadingTheme.availableFonts`:

| Font | Category |
|------|----------|
| Georgia | Serif |
| Palatino | Serif |
| Times New Roman | Serif |
| Helvetica | Sans-serif |
| Arial | Sans-serif |
| Verdana | Sans-serif |
| Courier New | Monospace |
| Menlo | Monospace |

No custom or bundled fonts are used — all fonts ship with macOS.

## Font Modes

### Single Font (default)

One font is applied to all content. The CSS injection sets `font-family` on `body` and forces inheritance on all elements with `* { font-family: inherit !important }`.

### Font Pairing (opt-in)

Six curated pairings are available, defined in `FontPairing.pairings`. Each pairing specifies a header font and a body font designed to contrast well together:

| Pairing | Headers | Body |
|---------|---------|------|
| Helvetica + Georgia | Helvetica (sans) | Georgia (serif) |
| Helvetica + Palatino | Helvetica (sans) | Palatino (serif) |
| Arial + Georgia | Arial (sans) | Georgia (serif) |
| Georgia + Helvetica | Georgia (serif) | Helvetica (sans) |
| Palatino + Helvetica | Palatino (serif) | Helvetica (sans) |
| Verdana + Georgia | Verdana (sans) | Georgia (serif) |

Users select a pairing from a single dropdown rather than choosing fonts independently. This ensures every combination looks good.

## How It Works

### CSS Injection

`ThemeManager.applyStyles(to:fontFamily:bodyFont:)` generates JavaScript that creates or updates a `<style id="focus-theme">` element in the chapter's HTML `<head>`.

**Single font mode** (`bodyFont` is `nil`):
```css
body { font-family: 'Georgia', serif !important; }
* { font-family: inherit !important; }
```

**Font pairing mode** (`bodyFont` is set):
```css
body { font-family: 'Georgia', serif !important; }
* { font-family: inherit !important; }
h1, h2, h3, h4, h5, h6 { font-family: 'Helvetica', sans-serif !important; }
```

The heading rule comes after the universal `*` rule, so it takes precedence.

### Data Flow

1. **Athenaeum settings** — `UserSettings` stores `defaultFont` and an optional `fontPairingId`. Persisted via `SettingsRepository` as key-value pairs in SQLite. When `fontPairingId` is `nil`, single-font mode is used.
2. **Opening a book** — `LibraryViewModel.openBook()` includes `fontFamily` and optionally `fontPairingId` in the `.openBook` notification.
3. **Reader initialization** — `ReaderView` passes font settings to `ReaderViewModel`, which stores `fontFamily` and `fontPairingId` as `@Published` properties and resolves `headerFont`/`bodyFontResolved` via `FontPairing.pairing(byId:)`.
4. **Applying styles** — `ReaderViewModel.applyThemeStyles()` calls `themeManager.applyStyles(to:fontFamily:bodyFont:)`, passing `bodyFont` only when a pairing is active.
5. **Runtime changes** — The reader toolbar font menu allows selecting a single font or a curated pairing. Changes are applied immediately.

### Octavo

The standalone reader (Octavo) has no persistent settings. Font pairing can be selected via the reader toolbar menu during a session but resets to the default (single font, Georgia) when reopened.

## Relevant Files

| File | Role |
|------|------|
| `Ligature/Sources/Ligature/Models/ReadingTheme.swift` | `availableFonts` list, `FontPairing` model and curated pairings |
| `Forma/Sources/Forma/Views/ThemeManager.swift` | CSS generation and injection |
| `Forma/Sources/Forma/Views/ReaderViewModel.swift` | `fontFamily`, `fontPairingId`, resolved `headerFont`/`bodyFontResolved` |
| `Forma/Sources/Forma/Views/ReaderView.swift` | Toolbar font menu with single font + pairing submenus |
| `Athenaeum/Models/UserSettings.swift` | `defaultFont`, `fontPairingId` fields |
| `Athenaeum/Database/SettingsRepository.swift` | Persists font settings to SQLite |
| `Athenaeum/Views/SettingsView.swift` | Settings UI with font picker and pairing dropdown |
| `Athenaeum/Views/LibraryViewModel.swift` | Passes font settings when opening books |

## Adding a New Pairing

1. Add a `FontPairing` entry to `FontPairing.pairings` in `ReadingTheme.swift`.
2. Add the localization key (`fontPairing.newId`) to all `.strings` files in Athenaeum and Forma resources.
3. No other changes needed — all pickers and menus read from `FontPairing.pairings` dynamically.

## Adding a New Font

1. Add the font name to `ReadingTheme.availableFonts` in `ReadingTheme.swift`.
2. Ensure the font is available on the target macOS version (13.0+).
3. Consider adding new pairings that use the font.
4. No other changes needed — all pickers and menus read from `availableFonts` dynamically.
