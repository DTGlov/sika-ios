import SwiftUI

/// Sub-route picker for the 131-entry currency catalog.
/// Search filters by code / name / symbol; popular currencies pinned to top
/// when search is empty. Save commits the change via HTTP/Bearer.
struct CurrencyPickerView: View {
    @Environment(AppState.self) private var appState
    @Environment(ToastManager.self) private var toasts
    @Environment(\.dismiss) private var dismiss

    @State private var search: String = ""
    @State private var selectedCode: String
    @State private var isSaving = false

    private let goldColor = Color(hex: 0xD4A017)
    private let darkText = Color(hex: 0x0E1A2E)

    init(currentCode: String) {
        _selectedCode = State(initialValue: currentCode)
    }

    private var filtered: [Currency] {
        CurrencyCatalog.filtered(by: search)
    }

    private var canSave: Bool {
        !isSaving && selectedCode != currentProfileCode
    }

    private var currentProfileCode: String {
        if case .authenticated(let profile) = appState.flow {
            return profile.currency
        }
        return "GHS"
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filtered) { currency in
                        row(currency)
                        Divider().padding(.leading, 16)
                    }
                }
            }

            saveBar
        }
        .background(SikaTheme.Color.background)
        .navigationTitle("Currency")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(SikaTheme.Color.mutedForeground)
            TextField("Search currencies", text: $search)
                .font(SikaTheme.Typography.sans(14))
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
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

    private func row(_ currency: Currency) -> some View {
        let isSelected = currency.code == selectedCode
        return Button {
            selectedCode = currency.code
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(currency.code)
                        .font(SikaTheme.Typography.sans(14, weight: .semibold))
                        .foregroundStyle(SikaTheme.Color.foreground)
                    Text(currency.name)
                        .font(SikaTheme.Typography.sans(11))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer()
                Text(currency.symbol)
                    .font(SikaTheme.Typography.sans(13))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(goldColor)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isSelected ? goldColor.opacity(0.05) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var saveBar: some View {
        Button {
            Task { await save() }
        } label: {
            HStack {
                if isSaving {
                    ProgressView().scaleEffect(0.85).tint(darkText)
                }
                Text("Save")
                    .font(SikaTheme.Typography.sans(15, weight: .semibold))
                    .foregroundStyle(canSave ? darkText : SikaTheme.Color.mutedForeground)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(canSave ? goldColor : SikaTheme.Color.muted)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(SikaTheme.Color.background.opacity(0.95))
    }

    private func save() async {
        guard canSave else { return }
        isSaving = true
        defer { isSaving = false }
        let ok = await appState.updateCurrency(selectedCode)
        if ok {
            toasts.show("Currency updated", kind: .success)
            dismiss()
        } else {
            toasts.show("Failed to update currency", kind: .error)
        }
    }
}
