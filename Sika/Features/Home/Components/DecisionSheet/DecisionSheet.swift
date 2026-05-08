import SwiftUI

/// Bottom sheet hosting the 4-phase Should I Buy flow.
/// Phase machine in DecisionSheetViewModel.
///
/// Header behavior mirrors web:
/// - "Here's the read" title appears ONLY in the result phase
/// - X close button always visible (top-right)
struct DecisionSheet: View {
    @State private var viewModel = DecisionSheetViewModel()
    @Environment(\.dismiss) private var dismiss
    /// Injected by parent — switches the main tab to Transactions.
    let onBought: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                switch viewModel.phase {
                case .input:
                    DecisionInputView(viewModel: viewModel)
                case .loading:
                    DecisionLoadingView()
                case .result:
                    if let decision = viewModel.decision {
                        DecisionResultView(
                            decision: decision,
                            onSkip: {
                                Task {
                                    _ = await viewModel.resolve(outcome: .skipped)
                                    dismiss()
                                }
                            },
                            onBought: {
                                Task {
                                    let shouldNavigate = await viewModel.resolve(outcome: .bought)
                                    dismiss()
                                    if shouldNavigate { onBought() }
                                }
                            }
                        )
                    }
                case .error(let message):
                    DecisionErrorView(message: message, onRetry: viewModel.retry)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .background(SikaTheme.Color.background)
    }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .center) {
            if viewModel.phase.isResult {
                Text("Here's the read")
                    .font(SikaTheme.Typography.sans(18, weight: .bold))
                    .foregroundStyle(SikaTheme.Color.foreground)
            } else {
                Spacer()
            }

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.mutedForeground)
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}
