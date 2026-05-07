import SwiftUI

/// Stylized EMV chip rendered as SwiftUI shapes.
/// Approximation of web's chip.tsx: rounded outer rectangle + 3×3 grid of contacts.
/// Refine in Phase 6 if a more faithful path is desired.
struct EMVChip: View {
    let primary: Color
    let secondary: Color
    var size: CGFloat = 36

    var body: some View {
        let height = size * 0.78
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.15)
                .fill(primary.opacity(0.85))
                .frame(width: size, height: height)

            VStack(spacing: size * 0.05) {
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: size * 0.05) {
                        ForEach(0..<3, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: size * 0.03)
                                .fill(secondary.opacity(0.55))
                                .frame(width: size * 0.22, height: size * 0.18)
                        }
                    }
                }
            }
        }
        .frame(width: size, height: height)
    }
}
