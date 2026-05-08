import SwiftUI

/// Detail view for today's DailyDigest. Renders 4 story cards in a
/// scrollable list. Auto-marks digest read after 10 seconds via SwiftUI's
/// `.task` pattern (Task cancels naturally on view disappear).
///
/// Mirror of src/app/(app)/daily/page.tsx (the entire 200-line file).
/// The system NavigationStack provides the back chevron + "Sika Daily"
/// title — no custom sticky header needed.
struct DailyDigestDetailView: View {
    let digest: DailyDigest
    let isInitiallyRead: Bool
    let onMarkRead: () async -> Void

    @State private var isReadLocal: Bool
    @State private var hasStartedTimer = false

    /// Mirror of AUTO_READ_DELAY_MS from src/app/(app)/daily/page.tsx:28.
    private static let autoReadDelay: Duration = .seconds(10)

    init(
        digest: DailyDigest,
        isInitiallyRead: Bool,
        onMarkRead: @escaping () async -> Void
    ) {
        self.digest = digest
        self.isInitiallyRead = isInitiallyRead
        self.onMarkRead = onMarkRead
        self._isReadLocal = State(initialValue: isInitiallyRead)
    }

    private static let inputFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()

    /// Web uses `format(...,'EEEE, MMMM d, yyyy')` from date-fns —
    /// "Friday, May 8, 2026" style. Match exactly.
    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d, yyyy"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private var dateLabel: String {
        guard let date = Self.inputFormatter.date(from: digest.digestDate) else { return "" }
        return Self.displayFormatter.string(from: date)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SikaTheme.Spacing.md) {
                headerBlock

                VStack(spacing: 12) {
                    ForEach(digest.stories) { story in
                        DailyStoryCard(story: story)
                    }
                }

                markReadFooter
                    .padding(.top, SikaTheme.Spacing.md)
            }
            .padding(.horizontal, SikaTheme.Spacing.lg)
            .padding(.top, SikaTheme.Spacing.lg)
            .padding(.bottom, 96)  // matches web's pb-24
        }
        .navigationTitle("Sika Daily")
        .navigationBarTitleDisplayMode(.inline)
        .background(SikaTheme.Color.background)
        .task {
            // Auto-mark read after 10 seconds.
            // Mirror of useEffect at page.tsx:102-109.
            // Task cancels naturally if view disappears before 10s — try? swallows the cancellation.
            guard !isReadLocal, !hasStartedTimer else { return }
            hasStartedTimer = true
            try? await Task.sleep(for: Self.autoReadDelay)
            await markReadIfNeeded()
        }
    }

    private var headerBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(dateLabel)
                .font(SikaTheme.Typography.sans(14))
                .foregroundStyle(SikaTheme.Color.mutedForeground)

            if digest.isFallback {
                Text("CATCH UP FROM YESTERDAY")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(SikaTheme.Color.sikaWarning)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(SikaTheme.Color.sikaWarning.opacity(0.10))
                    )
            }
        }
    }

    @ViewBuilder
    private var markReadFooter: some View {
        if isReadLocal {
            Text("✓ Read")
                .font(SikaTheme.Typography.sans(12))
                .foregroundStyle(SikaTheme.Color.mutedForeground.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 8)
        } else {
            Button {
                Task { await markReadIfNeeded() }
            } label: {
                Text("Mark as read")
                    .font(SikaTheme.Typography.sans(14))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(SikaTheme.Color.border, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func markReadIfNeeded() async {
        guard !isReadLocal else { return }
        isReadLocal = true
        await onMarkRead()
    }
}
