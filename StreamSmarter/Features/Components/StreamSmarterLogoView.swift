import SwiftUI

/// Reusable logo component — faithful port of StreamSmarterLogo composable in RetroTVComponents.kt.
/// Tap 10 times within 500ms between taps to trigger onLogoClick with a magenta flash.
struct StreamSmarterLogoView: View {
    var iconSize: CGFloat = 32
    var fontSize: CGFloat = 32
    var taglineSize: CGFloat = 8
    var statusMessage: String? = nil
    var onLogoClick: () -> Void = {}

    @State private var clickCount = 0
    @State private var lastClickTime: Date = .distantPast
    @State private var flashOpacity: Double = 0

    private let brandingNavy  = Color(red: 0.0,   green: 0.2,   blue: 0.4)   // #003366
    private let brandingGreen = Color(red: 0.0,   green: 0.667, blue: 0.4)   // #00AA66
    private let magenta       = Color(red: 1.0,   green: 0.0,   blue: 1.0)

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                ZStack {
                    Image("StreamSmarterLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: iconSize, height: iconSize)
                    magenta
                        .opacity(flashOpacity)
                        .frame(width: iconSize, height: iconSize)
                }

                Text("Stream")
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(flashOpacity > 0 ? magenta : brandingNavy)

                Text("$marter")
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundColor(flashOpacity > 0 ? magenta : brandingGreen)
            }

            Text("TRACK * WATCH * SAVE")
                .font(.system(size: taglineSize, weight: .bold))
                .foregroundColor(flashOpacity > 0 ? magenta : brandingNavy)
                .tracking(4)

            if let message = statusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .transition(.opacity)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { handleTap() }
    }

    private func handleTap() {
        let now = Date()
        if now.timeIntervalSince(lastClickTime) < 0.5 {
            clickCount += 1
        } else {
            clickCount = 1
        }
        lastClickTime = now

        if clickCount >= 10 {
            clickCount = 0
            onLogoClick()
            flashLogo()
        }
    }

    // 3 on/off cycles × 150ms each = 900ms, matching Android's repeatable(6, tween(150), Reverse)
    private func flashLogo() {
        Task {
            for _ in 0..<3 {
                withAnimation(.linear(duration: 0.15)) { flashOpacity = 0.4 }
                try? await Task.sleep(for: .milliseconds(150))
                withAnimation(.linear(duration: 0.15)) { flashOpacity = 0 }
                try? await Task.sleep(for: .milliseconds(150))
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black
        StreamSmarterLogoView()
    }
}
