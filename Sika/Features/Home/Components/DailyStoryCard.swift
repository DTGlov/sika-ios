import SwiftUI

/// One news story card on the /daily detail page.
/// PASSIVE — no tap target on v1 (matches web; story tap deferred to v2).
///
/// Visual spec mirrors web's StoryCard in src/app/(app)/daily/page.tsx:30-59:
/// - Outer: card bg, 1pt border, rounded 16pt, overflow-hidden
/// - Hero image (when image_url is non-nil): full-width 192pt height, aspect-fill;
///   hidden entirely if load fails (matches web's ImageWithFallback onError → null)
/// - Body padding 16pt, vertical stack with 8pt spacing:
///   1. Category label uppercase 10pt bold brand-colored, tracking 1.5
///   2. Emoji 20pt + title 14pt semibold foreground
///   3. Summary 14pt muted
///   4. Source attribution "— {sourceName}" 12pt muted at 70%
struct DailyStoryCard: View {
    let story: DailyStory

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            heroImage

            VStack(alignment: .leading, spacing: 8) {
                Text(story.category.label.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(story.category.brandColor)

                HStack(alignment: .top, spacing: 8) {
                    Text(story.emoji)
                        .font(.system(size: 20))
                    Text(story.title)
                        .font(SikaTheme.Typography.sans(14, weight: .semibold))
                        .foregroundStyle(SikaTheme.Color.foreground)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(story.summary)
                    .font(SikaTheme.Typography.sans(14))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text("— \(story.sourceName)")
                    .font(SikaTheme.Typography.sans(12))
                    .foregroundStyle(SikaTheme.Color.mutedForeground.opacity(0.7))
            }
            .padding(16)
        }
        .background(SikaTheme.Color.card)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(SikaTheme.Color.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        // INTENTIONAL: NO onTapGesture. Web v1 does not ship story tap.
    }

    @ViewBuilder
    private var heroImage: some View {
        if let urlStr = story.imageUrl,
           !urlStr.isEmpty,
           let url = URL(string: urlStr) {
            // Layout fix (round 2): Fix A's inner-image .scaledToFill()
            // + flexible-fill frame still leaked source image dimensions
            // on device, because `.frame(maxWidth: .infinity, maxHeight:
            // .infinity)` doesn't act as a hard cap — AsyncImage's child
            // can still report a larger natural size inside an unbounded-
            // height parent (ScrollView).
            //
            // Robust pattern: invert the structure. Color.clear sized at
            // 192pt is the authoritative size declaration. AsyncImage
            // rides in `.overlay`, which is layout-passive — overlays
            // take the size of their host and cannot expand it. This
            // breaks the intrinsic-size leak chain. `.clipped()` outermost
            // trims any pixel overflow from `.scaledToFill()` inside the
            // overlay.
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 192)              // h-48 on web — authoritative cap
                .overlay(
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Color.clear
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            // Match web's ImageWithFallback onError → null
                            Color.clear
                        @unknown default:
                            Color.clear
                        }
                    }
                )
                .clipped()
        }
    }
}
