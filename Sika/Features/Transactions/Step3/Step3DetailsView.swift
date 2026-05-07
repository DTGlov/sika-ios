import SwiftUI

/// Step 3 content of the Add Transaction wizard: "Any details?"
/// Note (optional) + Date + expandable "Paid from a target?" section.
struct Step3DetailsView: View {
    @Bindable var viewModel: AddTransactionWizardViewModel

    @State private var isTargetSectionExpanded = false
    @AppStorage("addTransaction.targetTutorialDismissed") private var hasSeenTargetTutorial = false
    @State private var showDatePicker = false
    @State private var showEmptyTargetsSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: SikaTheme.Spacing.lg) {
            Text("Any details?")
                .font(SikaTheme.Typography.sans(28, weight: .bold))
                .foregroundStyle(SikaTheme.Color.foreground)
                .padding(.horizontal, SikaTheme.Spacing.lg)

            ScrollView {
                VStack(alignment: .leading, spacing: SikaTheme.Spacing.lg) {
                    noteSection
                    dateSection

                    // Transfer transactions don't link to targets — hide section.
                    if viewModel.selectedType != .transfer {
                        targetSection
                    }

                    Spacer().frame(height: SikaTheme.Spacing.lg)
                }
                .padding(.horizontal, SikaTheme.Spacing.lg)
                .padding(.top, SikaTheme.Spacing.sm)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(date: $viewModel.transactionDate, isPresented: $showDatePicker)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showEmptyTargetsSheet) {
            EmptyTargetsSheet(isPresented: $showEmptyTargetsSheet)
                .presentationDetents([.medium])
        }
    }

    // MARK: - Note Section

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: SikaTheme.Spacing.sm) {
            Text("Note (optional)")
                .font(SikaTheme.Typography.sans(13))
                .foregroundStyle(SikaTheme.Color.mutedForeground)

            TextField(
                "",
                text: $viewModel.note,
                prompt: Text("What was this for?")
                    .foregroundColor(SikaTheme.Color.placeholderText),
                axis: .vertical
            )
            .font(SikaTheme.Typography.sans(15))
            .foregroundStyle(SikaTheme.Color.foreground)
            .lineLimit(1...4)
            .padding(.horizontal, SikaTheme.Spacing.md)
            .padding(.vertical, SikaTheme.Spacing.md)
            .background(SikaTheme.Color.muted)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Date Section

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: SikaTheme.Spacing.sm) {
            Text("Date")
                .font(SikaTheme.Typography.sans(13))
                .foregroundStyle(SikaTheme.Color.mutedForeground)

            Button(action: { showDatePicker = true }) {
                HStack {
                    Text(formattedDate(viewModel.transactionDate))
                        .font(SikaTheme.Typography.sans(15, weight: .semibold))
                        .foregroundStyle(SikaTheme.Color.foreground)
                    Spacer()
                    Image(systemName: "calendar")
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                        .font(.system(size: 14))
                }
                .padding(.horizontal, SikaTheme.Spacing.md)
                .padding(.vertical, SikaTheme.Spacing.md)
                .background(SikaTheme.Color.muted)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }

    // MARK: - Target Section

    private var targetSection: some View {
        VStack(alignment: .leading, spacing: SikaTheme.Spacing.sm) {
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    isTargetSectionExpanded.toggle()
                }
            }) {
                HStack(spacing: SikaTheme.Spacing.xs) {
                    Image(systemName: isTargetSectionExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                    Text("Paid from a target?")
                        .font(SikaTheme.Typography.sans(14, weight: .semibold))
                        .foregroundStyle(SikaTheme.Color.foreground)
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            if isTargetSectionExpanded {
                VStack(alignment: .leading, spacing: SikaTheme.Spacing.md) {
                    if !hasSeenTargetTutorial {
                        tutorialCard
                    }
                    targetPickerRow
                    Text("Perpetual goals (like Life Savings) don't appear here — they're protected.")
                        .font(SikaTheme.Typography.sans(12))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Tutorial Card

    private var tutorialCard: some View {
        VStack(alignment: .leading, spacing: SikaTheme.Spacing.md) {
            HStack {
                Text("What's a target?")
                    .font(SikaTheme.Typography.sans(15, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                Spacer()
                Button(action: dismissTutorial) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(SikaTheme.Color.mutedForeground)
                        .padding(SikaTheme.Spacing.xs)
                }
                .buttonStyle(.plain)
            }

            Text("For big expenses you're saving toward — trips, electronics, rent. Save monthly toward the target amount. When you actually pay, flag it here so Sika doesn't double-count — the saving already accounted for it.")
                .font(SikaTheme.Typography.sans(13))
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .lineSpacing(2)

            Button(action: dismissTutorial) {
                Text("Got it")
                    .font(SikaTheme.Typography.sans(14, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.primaryForeground)
                    .padding(.horizontal, SikaTheme.Spacing.lg)
                    .padding(.vertical, SikaTheme.Spacing.sm)
                    .background(Capsule().fill(SikaTheme.Color.sikaAccent))
            }
            .buttonStyle(.plain)
        }
        .padding(SikaTheme.Spacing.md)
        .background(SikaTheme.Color.background)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(SikaTheme.Color.sikaAccent, lineWidth: 1)
        )
    }

    private func dismissTutorial() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            hasSeenTargetTutorial = true
        }
    }

    // MARK: - Target Picker Row

    private var targetPickerRow: some View {
        Button(action: { showEmptyTargetsSheet = true }) {
            HStack {
                Text("— Not from a target")
                    .font(SikaTheme.Typography.sans(15, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.foreground)
                Spacer()
                VStack(spacing: 2) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 9, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(SikaTheme.Color.mutedForeground)
            }
            .padding(.horizontal, SikaTheme.Spacing.md)
            .padding(.vertical, SikaTheme.Spacing.md)
            .background(SikaTheme.Color.muted)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
