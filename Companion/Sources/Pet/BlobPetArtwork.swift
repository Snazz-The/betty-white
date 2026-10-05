import SwiftUI

/// Placeholder character: a vector blob with eyes and a mouth, plus an SF Symbol badge per state.
struct BlobPetArtwork: PetArtwork {
    let size = CGSize(width: 120, height: 130)

    /// The blob body, in character coordinates.
    private var bodyRect: CGRect { CGRect(x: 14, y: 30, width: 92, height: 92) }

    func view(for state: CompanionState) -> AnyView {
        AnyView(BlobView(state: state, bodyRect: bodyRect).frame(width: size.width, height: size.height))
    }

    func contains(_ point: CGPoint) -> Bool {
        let rect = bodyRect
        let dx = (point.x - rect.midX) / (rect.width / 2)
        let dy = (point.y - rect.midY) / (rect.height / 2)
        return dx * dx + dy * dy <= 1 || badgeRect.contains(point)
    }

    private var badgeRect: CGRect { CGRect(x: 72, y: 0, width: 44, height: 40) }
}

private struct BlobView: View {
    let state: CompanionState
    let bodyRect: CGRect

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            ZStack(alignment: .topLeading) {
                blob(t: t)
                    .frame(width: bodyRect.width, height: bodyRect.height)
                    .offset(x: bodyRect.minX, y: bodyRect.minY + bob(t))
                if let badge {
                    Image(systemName: badge)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white, Color.accentColor)
                        .symbolRenderingMode(.palette)
                        .padding(6)
                        .background(Circle().fill(.ultraThinMaterial))
                        .offset(x: 76, y: 2 + bob(t) * 0.5)
                        .scaleEffect(badgeScale(t))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private var badge: String? {
        switch state {
        case .idle: return nil
        case .listening: return "ear.fill"
        case .thinking: return "ellipsis"
        case .talking: return "waveform"
        }
    }

    private func bob(_ t: Double) -> CGFloat {
        switch state {
        case .idle: return CGFloat(sin(t * 1.6)) * 3
        case .thinking: return CGFloat(sin(t * 4)) * 2
        case .talking: return CGFloat(abs(sin(t * 9))) * -3
        case .listening: return 0
        }
    }

    private func badgeScale(_ t: Double) -> CGFloat {
        state == .listening ? 1 + CGFloat(sin(t * 5)) * 0.08 : 1
    }

    private func blob(t: Double) -> some View {
        let blinking = state != .thinking && t.truncatingRemainder(dividingBy: 4.2) < 0.13
        let mouthOpen: CGFloat = state == .talking ? 4 + CGFloat(abs(sin(t * 12))) * 10 : 3
        let eyeShift: CGFloat = state == .thinking ? 6 : 0

        return ZStack {
            Ellipse()
                .fill(LinearGradient(colors: [Color(red: 0.55, green: 0.78, blue: 1.0), Color(red: 0.36, green: 0.52, blue: 0.98)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(Ellipse().stroke(.black.opacity(0.15), lineWidth: 1))
                .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
                .scaleEffect(x: state == .listening ? 1.04 : 1, y: state == .listening ? 0.97 : 1)

            HStack(spacing: 18) {
                eye(blinking: blinking)
                eye(blinking: blinking)
            }
            .offset(x: eyeShift, y: -10 - (eyeShift / 2))

            Capsule()
                .fill(.black.opacity(0.75))
                .frame(width: state == .listening ? 10 : 18, height: mouthOpen)
                .offset(y: 18)
        }
    }

    private func eye(blinking: Bool) -> some View {
        Capsule()
            .fill(.black.opacity(0.85))
            .frame(width: 10, height: blinking ? 2 : 14)
    }
}
