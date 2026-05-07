import SwiftUI

/// Sheet-presented graphical date picker for the wizard's Date row.
/// Uses iOS DatePicker with our gold tint.
struct DatePickerSheet: View {
    @Binding var date: Date
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Select date",
                    selection: $date,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(SikaTheme.Color.sikaAccent)
                .padding(.horizontal, SikaTheme.Spacing.lg)

                Spacer()
            }
            .background(SikaTheme.Color.background)
            .navigationTitle("Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .font(SikaTheme.Typography.sans(16, weight: .semibold))
                    .foregroundStyle(SikaTheme.Color.sikaAccent)
                }
            }
        }
    }
}
