// Copyright 2026 Link Dupont
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation

/// Registry for build-time secrets that are injected by the app target
/// at startup. The framework cannot access the generated `Secrets` type
/// directly since it lives in the app target.
public enum SecretsProvider {
    /// The Tavily API key, injected from `Secrets.tavilyAPIKey` at app startup.
    public nonisolated(unsafe) static var tavilyAPIKey: String?
}
