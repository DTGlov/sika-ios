import SwiftUI

/// Day group card with header strip + divider-separated rows.
/// Mirror of web's day-grouped list.
struct TransactionDayCard: View {
    let dateStr: String
    let rows: [TransactionListRow]
    let currencyCode: String
    let onDelete: (UUID) async -> Void
    /// Optional edit handler; nil from non-T1 surfaces (e.g. Goals contributions).
    var onEdit: ((TransactionListRow) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(headerText)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(SikaTheme.Color.mutedForeground)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                TransactionRowView(
                    row: row,
                    currencyCode: currencyCode,
                    onDelete: { await onDelete(row.id) },
                    onEdit: onEdit.map { handler in { handler(row) } }
                )
                if index < rows.count - 1 {
                    Divider()
                        .padding(.leading, 68)
                }
            }
        }
        .background(SikaTheme.Color.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(SikaTheme.Color.border, lineWidth: 1)
        )
    }

    /// "TODAY · MAY 9, 2026" / "YESTERDAY · MAY 8, 2026" / "WEDNESDAY · MAY 7, 2026"
    private var headerText: String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = .current
        guard let date = parser.date(from: dateStr) else {
            return dateStr.uppercased()
        }

        let cal = Calendar.current
        let label: String
        if cal.isDateInToday(date) {
            label = "TODAY"
        } else if cal.isDateInYesterday(date) {
            label = "YESTERDAY"
        } else {
            let weekday = DateFormatter()
            weekday.dateFormat = "EEEE"
            label = weekday.string(from: date).uppercased()
        }

        let monthDay = DateFormatter()
        monthDay.dateFormat = "MMM d, yyyy"
        return "\(label) · \(monthDay.string(from: date).uppercased())"
    }
}
