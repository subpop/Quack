import Testing
import Foundation
@testable import QuackKit

struct MLXLoadStateTests {
    @Test func idleState() {
        if case .idle = MLXLoadState.idle {} else {
            Issue.record("Expected idle state")
        }
    }

    @Test func downloadingState() {
        let state = MLXLoadState.downloading(progress: 0.5)
        if case .downloading(let progress) = state {
            #expect(progress == 0.5)
        } else {
            Issue.record("Expected downloading state")
        }
    }

    @Test func failedState() {
        let state = MLXLoadState.failed("GPU memory exhausted")
        if case .failed(let msg) = state {
            #expect(msg == "GPU memory exhausted")
        } else {
            Issue.record("Expected failed state")
        }
    }

    @Test func loadingState() {
        if case .loading = MLXLoadState.loading {} else {
            Issue.record("Expected loading state")
        }
    }

    @Test func readyState() {
        if case .ready = MLXLoadState.ready {} else {
            Issue.record("Expected ready state")
        }
    }
}
