import SwiftUI

enum SikaTextFieldKind {
    case email
    case password
    case name
    case text
}

struct SikaTextField: View {
    let label: String
    @Binding var text: String
    var kind: SikaTextFieldKind = .text
    var placeholder: String? = nil
    var error: String? = nil

    @FocusState private var isFocused: Bool
    @State private var isPasswordRevealed: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: SikaTheme.Spacing.xs) {
            Text(label)
                .font(SikaTheme.Typography.sans(13, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)

            ZStack {
                fieldView
            }
            .padding(.horizontal, SikaTheme.Spacing.md)
            .frame(height: 48)
            .background(SikaTheme.Color.card)
            .overlay(
                RoundedRectangle(cornerRadius: SikaTheme.Radius.lg)
                    .stroke(borderColor, lineWidth: isFocused ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: SikaTheme.Radius.lg))
            .animation(.easeOut(duration: 0.15), value: isFocused)

            if let error {
                Text(error)
                    .font(SikaTheme.Typography.sans(12))
                    .foregroundStyle(SikaTheme.Color.destructive)
            }
        }
    }

    @ViewBuilder
    private var fieldView: some View {
        HStack(spacing: SikaTheme.Spacing.sm) {
            Group {
                if kind == .password && !isPasswordRevealed {
                    SecureField("", text: $text, prompt: prompt)
                } else {
                    TextField("", text: $text, prompt: prompt)
                }
            }
            .font(SikaTheme.Typography.sans(15))
            .foregroundStyle(SikaTheme.Color.foreground)
            .focused($isFocused)
            .textInputAutocapitalization(autocapitalization)
            .autocorrectionDisabled(disableAutocorrection)
            .keyboardType(keyboardType)
            .textContentType(contentType)
            .submitLabel(submitLabel)

            if kind == .password {
                Button {
                    isPasswordRevealed.toggle()
                } label: {
                    Image(systemName: isPasswordRevealed ? "eye.slash" : "eye")
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                }
                .accessibilityLabel(isPasswordRevealed ? "Hide password" : "Show password")
            }
        }
    }

    private var borderColor: Color {
        if error != nil { return SikaTheme.Color.destructive }
        if isFocused { return SikaTheme.Color.sikaAccent }
        return SikaTheme.Color.border
    }

    private var autocapitalization: TextInputAutocapitalization {
        switch kind {
        case .email, .password: return .never
        case .name: return .words
        case .text: return .sentences
        }
    }

    private var disableAutocorrection: Bool {
        switch kind {
        case .email, .password: return true
        case .name, .text: return false
        }
    }

    private var keyboardType: UIKeyboardType {
        switch kind {
        case .email: return .emailAddress
        case .password, .name, .text: return .default
        }
    }

    private var contentType: UITextContentType? {
        switch kind {
        case .email: return .emailAddress
        case .password: return .password
        case .name: return .name
        case .text: return nil
        }
    }

    private var submitLabel: SubmitLabel {
        switch kind {
        case .email, .name, .text: return .next
        case .password: return .go
        }
    }

    private var prompt: Text? {
        guard let placeholder, !placeholder.isEmpty else { return nil }
        return Text(placeholder)
            .foregroundColor(SikaTheme.Color.placeholderText)
    }
}
