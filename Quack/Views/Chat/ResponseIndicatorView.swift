import SwiftUI

/// Animated response indicator that sweeps a highlighted segment back and
/// forth along a track, similar to a Cylon eye / Knight Rider scanner.
///
/// When the user has Reduce Motion enabled, the indicator pulses opacity
/// instead of moving.
struct ResponseIndicatorView: View {
    @State private var isAnimating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let trackWidth: CGFloat = 64
    private let trackHeight: CGFloat = 3
    private let glowWidth: CGFloat = 16
    private let duration: Double = 0.7

    var body: some View {
        ZStack {
            // Dim background track
            Capsule()
                .fill(.tint.opacity(0.2))
                .frame(width: trackWidth, height: trackHeight)

            // Bright sweep element
            Capsule()
                .fill(.tint)
                .frame(width: glowWidth, height: trackHeight)
                .offset(x: reduceMotion ? 0 : (isAnimating ? (trackWidth - glowWidth) / 2 : -(trackWidth - glowWidth) / 2))
                .opacity(reduceMotion ? (isAnimating ? 1.0 : 0.3) : 1.0)
                .animation(
                    reduceMotion
                        ? .linear(duration: duration).repeatForever(autoreverses: true)
                        : .easeInOut(duration: duration).repeatForever(autoreverses: true),
                    value: isAnimating
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Thinking")
        .onAppear {
            isAnimating = true
        }
    }
}

#Preview {
    ResponseIndicatorView()
        .padding()
}
