# Localization

Athenaeum supports multiple languages. All user-facing strings are localized using Apple's standard `.strings` file format with `NSLocalizedString`.

## Supported Languages

| Code | Language |
|------|----------|
| `en` | English (default) |
| `es` | Spanish |
| `it` | Italian |

## File Structure

Each target has its own localization resources:

```
Forma/Sources/Forma/Resources/
├── en.lproj/Localizable.strings    # Shared reader UI strings
├── es.lproj/Localizable.strings
└── it.lproj/Localizable.strings

Octavo/Resources/
├── en.lproj/Localizable.strings    # Reader app strings
├── es.lproj/Localizable.strings
└── it.lproj/Localizable.strings

Athenaeum/Resources/
├── en.lproj/Localizable.strings    # Library app strings
├── es.lproj/Localizable.strings
└── it.lproj/Localizable.strings
```

### What lives where

- **Forma** — Strings used in the shared reader UI: toolbar labels, navigation buttons, mode labels, window title format.
- **Octavo** — Strings specific to the reader app: landing screen text, file open prompts, error messages.
- **Athenaeum** — Strings specific to the library app: library UI labels, settings, table columns, edit sheet, theme names, import errors.

## Adding a New Language

1. Create a new `.lproj` directory in each target's resources folder:
   ```sh
   mkdir -p Forma/Sources/Forma/Resources/fr.lproj
   mkdir -p Octavo/Resources/fr.lproj
   mkdir -p Athenaeum/Resources/fr.lproj
   ```

2. Copy the English `.strings` file as a starting point:
   ```sh
   cp Forma/Sources/Forma/Resources/en.lproj/Localizable.strings \
      Forma/Sources/Forma/Resources/fr.lproj/Localizable.strings
   ```

3. Translate the values (right side of `=`) in each copied file. Do not change the keys (left side).

4. Rebuild. SwiftPM automatically picks up new `.lproj` directories — no `Package.swift` changes needed.

## Adding New Strings

1. Add the key-value pair to **all** language `.strings` files in the relevant target.
2. Use `NSLocalizedString("key", bundle: bundle, comment: "")` in code, where `bundle` is:
   - `Bundle.module` for code in Octavo or Athenaeum
   - The file-level `bundle` constant (set to `Bundle.module`) in Forma's `ReaderView.swift`
3. For format strings, use `String(format: NSLocalizedString(...), args)` with `%d` for integers and `%@` for strings.

## String Keys Convention

- Simple words used directly as labels: use the English word as the key (e.g., `"Previous"`, `"Font"`)
- Structured keys for longer or contextual strings: use dot notation (e.g., `"landing.prompt"`, `"nav.mode.hint"`, `"title.progress"`)
- Format strings: include the format specifier in the key when the key is the English text (e.g., `"of %d"`)

## Testing

To test a specific locale without changing system settings, set the launch argument:

```sh
swift run Octavo -AppleLanguages "(es)"
```
