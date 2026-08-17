import Foundation

extension Date {
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    var relativeTimestamp: String {
        if Calendar.current.isDateInToday(self) {
            return formatted(date: .omitted, time: .shortened)
        }
        return Self.relativeFormatter.localizedString(for: self, relativeTo: .now)
    }
}
