import SwiftUI

struct TransactionSearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(SikaTheme.Color.mutedForeground)

            TextField("Search by note or amount…", text: $text)
                .font(SikaTheme.Typography.sans(14))
                .foregroundStyle(SikaTheme.Color.foreground)
                .submitLabel(.search)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(SikaTheme.Color.mutedForeground.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(SikaTheme.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(SikaTheme.Color.border, lineWidth: 1)
        )
    }
}
