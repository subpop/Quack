## 0.2.2 (7) (2026-04-27)

- 🐛 Fixed an issue running multiple MCP servers simultaneously

## 0.2.1 (6) (2026-04-24)

- 💥 Fixed an issue migrating from the SwiftData schema in 0.1.3

### Additional changes from 0.2.0

- 🧩 Skills support for loading specialized instruction sets
- 🤖 Default coding assistant with provider-specific system prompts and dynamic AGENTS.md injection
- 📂 Per-session working directories with folder picker (Cmd+Shift+N) so tools operate relative to a project
- 🌐 Environment context (`<env>` block) injected into prompts with working directory and platform info
- 🎨 Redesigned inspector with tab-based layout
- 💬 Improved chat session UX in inspector and new chat sheet
- ⚙️ General Settings with appearance option
- 💡 Response indicator replaces initial "Thinking" spinner
- ⬆️ AgentRunKit updated to 2.0.x
- 📊 os_signpost instrumentation for streaming markdown renderer profiling
- 🚨 MCP server error messages now surfaced to the user
- 🐛 Fix WebSearch tool not registering due to secret injection ordering
- 🐛 Fix MainView preview crash caused by customizable toolbar

## 0.2.0 (5) (2026-04-24)

- 🧩 Skills support for loading specialized instruction sets
- 🤖 Default coding assistant with provider-specific system prompts and dynamic AGENTS.md injection
- 📂 Per-session working directories with folder picker (Cmd+Shift+N) so tools operate relative to a project
- 🌐 Environment context (`<env>` block) injected into prompts with working directory and platform info
- 🎨 Redesigned inspector with tab-based layout
- 💬 Improved chat session UX in inspector and new chat sheet
- ⚙️ General Settings with appearance option
- 💡 Response indicator replaces initial "Thinking" spinner
- ⬆️ AgentRunKit updated to 2.0.x
- 📊 os_signpost instrumentation for streaming markdown renderer profiling
- 🚨 MCP server error messages now surfaced to the user
- 🐛 Fix WebSearch tool not registering due to secret injection ordering
- 🐛 Fix MainView preview crash caused by customizable toolbar

## 0.1.3 (4) (2026-04-16)

- 🧠 MLX provider with on-device model management and HuggingFace model browser
- 🤖 System prompt generation using on-device Foundation Model
- 🎨 Animated infographic in inspector session info section
- 🐛 Various bug fixes and improvements

## 0.1.2 (3) (2026-04-10)

- 🛠️ Built-in tools system with dedicated settings view
- 📊 Session statistics with token usage tracking
- 📈 Token stats bar displayed above the compose view
- 📋 Proper Markdown table rendering with SwiftUI Grid layout
- 🤖 Assistant avatars shown in sidebar session rows
- 🏗️ Moved DEVELOPMENT_TEAM to Secrets.xcconfig for cleaner project config
- 🎨 UI polish (increased compose field corner radius)
- 🐛 Fix Sparkle feed URL, internal streaming event refactor

## 0.1.1 (2) (2026-03-28)

- 📝 Export chat session transcripts
- 💬 Auto-generated chat session titles
- 🔔 User Notifications for tool call permission prompts
- 🔧 Persistent tool permissions and configurable max tool call rounds
- ✨ Improved tool call result display and message history
- 🎨 UI polish (rounded glass effect, layout tweaks)
- 🐛 Minor bug fixes and improvements

## 0.1.0 (1) (2026-03-27)

- 🎁 Initial app release
