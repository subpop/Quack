# Contributing to Quack

Thank you for your interest in contributing to Quack. This document explains how to get started.

## Getting Started

1. Fork and clone the repository.
2. Copy the secrets configuration template:
   ```sh
   cp Secrets.xcconfig.example Secrets.xcconfig
   ```
3. Fill in your values in `Secrets.xcconfig` (see the template for details). This file is gitignored and will not be committed.
4. Open `Quack.xcodeproj` in Xcode.
5. Build and run (Cmd+R) to verify everything works.

### Requirements

- macOS 26.0 or later
- Xcode with Swift 6.0 support

Dependencies are managed via Swift Package Manager and resolve automatically on first build.

### Optional API Keys

Some built-in tools require API keys configured via `Secrets.xcconfig`:

- **`TAVILY_API_KEY`** -- Enables the Web Search tool. Obtain one at https://app.tavily.com/home (free tier: 1,000 searches/month). If omitted, the Web Search tool is simply not available.

## Making Changes

1. Create a branch from `main` for your work.
2. Make your changes, following the conventions described below.
3. Run the tests (Cmd+U) and verify they pass.
4. Commit your changes with a clear, descriptive commit message.
5. Open a pull request against `main`.

## Code Style

- Follow standard Swift conventions and the existing patterns in the codebase.
- Use SwiftUI for all UI code.
- Use SwiftData `@Model` classes for persistent data.
- Use `@Observable` classes for services and state management.
- Prefer Swift's structured concurrency (`async`/`await`, `@MainActor`) over callbacks.
- Keep views small and focused; extract reusable components into their own files.

## Project Structure

```
Quack/
  Models/       SwiftData model definitions
  Services/     Business logic and LLM provider integrations
  Views/        SwiftUI views, organized by feature area
  Utilities/    Shared helpers
QuackTests/     Unit tests (Swift Testing framework)
```

## Testing

Tests use the Swift Testing framework (`import Testing`). Run them from Xcode with Cmd+U or from the command line:

```sh
xcodebuild test -project Quack.xcodeproj -scheme Quack
```

When adding new functionality, include tests where practical -- particularly for model logic, service behavior, and data transformations.

## Reporting Issues

Open an issue on the repository with:

- A clear description of the problem or feature request.
- Steps to reproduce (for bugs).
- Expected vs. actual behavior.
- macOS version and any relevant configuration details.

## License

By contributing, you agree that your contributions will be licensed under the [Apache License 2.0](LICENSE).
