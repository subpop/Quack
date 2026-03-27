# Quack

A native macOS AI chat client that connects to multiple LLM providers from a single interface, with full support for MCP (Model Context Protocol) tool use.

![Screenshot](./docs/Screenshot.png)

## Features

- **Multi-provider support** -- Chat with models from OpenAI, Anthropic, Google Gemini, Vertex AI, Ollama, Apple Intelligence (on-device), OpenRouter, Groq, Together, Mistral, and any OpenAI-compatible endpoint.
- **MCP integration** -- Connect external MCP servers for tool use with a three-tier permission model (Always Allow, Ask, Deny) and per-session server selection.
- **Assistants** -- Create reusable presets that bundle a provider, model, system prompt, parameters, and MCP servers together.
- **Chat management** -- Persistent conversation history, session pinning, archiving, search, and per-session model/parameter overrides.
- **Streaming responses** -- Live token streaming with reasoning/thinking model support and collapsible reasoning display.
- **Markdown rendering** -- Full CommonMark rendering of LLM output including code blocks, tables, lists, and more.
- **Secure credentials** -- API keys stored in the macOS Keychain.
- **Auto-updates** -- Built-in update mechanism via Sparkle.

## Requirements

- macOS 26.0 or later
- Xcode with Swift 6.0 support

## Building

Open the project in Xcode and build:

```sh
open Quack.xcodeproj
```

Select the **Quack** scheme and run (Cmd+R).

Dependencies are managed via Swift Package Manager and resolve automatically on first build.

## Running Tests

Run the test suite from Xcode (Cmd+U), or from the command line:

```sh
xcodebuild test -project Quack.xcodeproj -scheme Quack
```

## Supported Providers

| Provider | Connection |
|---|---|
| OpenAI | API key |
| Anthropic (Claude) | API key |
| Google Gemini | API key |
| Vertex AI (Gemini) | Google Cloud credentials |
| Vertex AI (Claude) | Google Cloud credentials |
| Apple Intelligence | On-device (no key required) |
| Ollama | Local server |
| OpenRouter | API key |
| Groq | API key |
| Together | API key |
| Mistral | API key |
| Custom (OpenAI-compatible) | Configurable endpoint + API key |

## License

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for details.
