import SwiftUI

/// Form for the input phase. 4 fields + "Let Sika decide" CTA.
/// Auto-focuses the item-name field 100ms after appearing.
struct DecisionInputView: View {
    @Bindable var viewModel: DecisionSheetViewModel
    @FocusState private var itemNameFocused: Bool

    private let goldColor = SikaTheme.Color.sikaAccent
    private let darkText  = SikaTheme.Color.primaryForeground
    private let greenColor = Color(hex: 0x00D9A3)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            itemNameField
            amountField
            bucketSelector
            urgencySelector

            Spacer(minLength: 8)

            Button {
                Task { await viewModel.ask() }
            } label: {
                Text("Let Sika decide")
                    .font(SikaTheme.Typography.sans(16, weight: .semibold))
                    .foregroundStyle(viewModel.canSubmit ? darkText : SikaTheme.Color.mutedForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(viewModel.canSubmit ? goldColor : SikaTheme.Color.muted)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canSubmit)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .task {
            try? await Task.sleep(for: .milliseconds(100))
            itemNameFocused = true
        }
    }

    private var itemNameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What is it?")
                .font(SikaTheme.Typography.sans(14, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)

            TextField("e.g. New headphones, Dinner at Kofe...",
                      text: $viewModel.itemName)
                .focused($itemNameFocused)
                .padding(.horizontal, 12)
                .frame(height: 48)
                .background(SikaTheme.Color.muted)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(itemNameFocused ? goldColor : Color.clear, lineWidth: 2)
                )
                .onSubmit {
                    if viewModel.canSubmit {
                        Task { await viewModel.ask() }
                    }
                }
        }
    }

    private var amountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("How much? (GHS)")
                .font(SikaTheme.Typography.sans(14, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)

            TextField("0.00", text: $viewModel.amountText)
                .keyboardType(.decimalPad)
                .padding(.horizontal, 12)
                .frame(height: 48)
                .background(SikaTheme.Color.muted)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onSubmit {
                    if viewModel.canSubmit {
                        Task { await viewModel.ask() }
                    }
                }
        }
    }

    private var bucketSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Which bucket?")
                .font(SikaTheme.Typography.sans(14, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)

            HStack(spacing: 8) {
                ForEach(PurchaseDecisionBucket.allCases) { b in
                    Button {
                        viewModel.bucket = b
                    } label: {
                        Text(b.displayLabel)
                            .font(SikaTheme.Typography.sans(14,
                                weight: viewModel.bucket == b ? .semibold : .regular))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(
                                viewModel.bucket == b
                                    ? b.color
                                    : SikaTheme.Color.mutedForeground
                            )
                            .background(
                                viewModel.bucket == b
                                    ? b.color.opacity(0.10)
                                    : SikaTheme.Color.muted
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        viewModel.bucket == b ? b.color : Color.clear,
                                        lineWidth: 1.5
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var urgencySelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Urgency?")
                .font(SikaTheme.Typography.sans(14, weight: .semibold))
                .foregroundStyle(SikaTheme.Color.foreground)

            HStack(spacing: 8) {
                ForEach(PurchaseUrgency.allCases) { u in
                    Button {
                        viewModel.toggleUrgency(u)
                    } label: {
                        Text(u.displayLabel)
                            .font(SikaTheme.Typography.sans(12,
                                weight: viewModel.urgency == u ? .semibold : .regular))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(
                                viewModel.urgency == u
                                    ? greenColor
                                    : SikaTheme.Color.mutedForeground
                            )
                            .background(
                                viewModel.urgency == u
                                    ? greenColor.opacity(0.10)
                                    : SikaTheme.Color.muted
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        viewModel.urgency == u ? greenColor : Color.clear,
                                        lineWidth: 1.5
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
