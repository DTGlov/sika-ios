import SwiftUI
import SafariServices

/// Plain text link at the bottom of Settings. Opens privacy policy in
/// SFSafariViewController.
struct PrivacyPolicyLink: View {
    @State private var showSafari = false

    // TODO: Confirm canonical URL with the team. Phase 8's HTTP client uses
    // the Vercel preview host; the public-facing privacy policy URL is
    // a separate concern. Hardcoding the Vercel /privacy path for now.
    private let url = URL(string: "https://sika-dlrl.vercel.app/privacy")!

    private let goldColor = Color(hex: 0xD4A017)

    var body: some View {
        Button {
            showSafari = true
        } label: {
            Text("Privacy policy")
                .font(SikaTheme.Typography.sans(12, weight: .semibold))
                .foregroundStyle(goldColor.opacity(0.9))
                .underline()
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .sheet(isPresented: $showSafari) {
            SafariView(url: url)
        }
    }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
