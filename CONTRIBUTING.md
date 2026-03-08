# Contributing to Athenaeum

Thank you for your interest in contributing!

## Getting Started

1. Fork the repository
2. Clone your fork
3. Create a feature branch: `git checkout -b my-feature`
4. Make your changes
5. Build and test: `swift build`
6. Commit your changes
7. Push to your fork and open a pull request

## Development Setup

- macOS 13.0+
- Swift 5.9+
- No external dependencies to install

```sh
swift build          # Build all targets
swift run Octavo     # Run the reader to test changes
```

## Project Layout

- **Athenaeum/** — Library app (database, import pipeline, library views)
- **Octavo/** — Reader app entry point
- **Forma/** — Shared UI library (reader views, theme management)
- **Ligature/** — Shared backend library (EPUB parsing, core models)

Both apps depend on Forma, which depends on Ligature. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for details.

## Guidelines

- Keep the project dependency-free. Prefer Foundation and system frameworks.
- Use Swift conventions: camelCase for variables/functions, PascalCase for types.
- All public API in Ligature and Forma should have `public` access control.
- Test your changes with various EPUB 2 and EPUB 3 files before submitting.

## Reporting Issues

Open an issue with:
- A clear description of the problem
- Steps to reproduce
- macOS version and Swift version
- The EPUB file that triggers the issue (if applicable)

## Pull Requests

- Keep PRs focused on a single change
- Include a description of what changed and why
- Ensure `swift build` succeeds with no warnings
