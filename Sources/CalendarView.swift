import SwiftUI

struct CalendarView: View {
    @Binding var selectedDate: Date
    @ObservedObject var videoStore: VideoStore

    @State private var displayedMonth: Date = Date()

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]

    private var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    private var daysInMonth: [Date?] {
        var days: [Date?] = []

        var components = calendar.dateComponents([.year, .month], from: displayedMonth)
        components.day = 1
        guard let firstOfMonth = calendar.date(from: components) else { return days }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        for _ in 1..<firstWeekday {
            days.append(nil)
        }

        guard let range = calendar.range(of: .day, in: .month, for: firstOfMonth) else { return days }
        for day in range {
            components.day = day
            if let date = calendar.date(from: components) {
                days.append(date)
            }
        }

        return days
    }

    private var videoDates: Set<String> {
        let year = calendar.component(.year, from: displayedMonth)
        let month = calendar.component(.month, from: displayedMonth)
        let videos = videoStore.videosForMonth(year: year, month: month)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return Set(videos.map { url in
            let name = url.deletingPathExtension().lastPathComponent
            return name.replacingOccurrences(of: "Blink_", with: "")
        })
    }

    var body: some View {
        VStack(spacing: 16) {
            header

            weekdayHeader

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(daysInMonth.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        DayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(date),
                            hasVideo: hasVideo(for: date),
                            isCurrentMonth: calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month)
                        )
                        .onTapGesture {
                            selectedDate = date
                        }
                    } else {
                        Color.clear
                            .frame(height: 36)
                    }
                }
            }

            Spacer()
        }
        .padding(20)
        .background(Theme.surface)
    }

    private var header: some View {
        HStack {
            Button {
                previousMonth()
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(Theme.textPrimary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(monthYearString)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Theme.textPrimary)

            Spacer()

            Button {
                nextMonth()
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundColor(Theme.textPrimary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
        }
    }

    private var weekdayHeader: some View {
        HStack {
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func hasVideo(for date: Date) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = formatter.string(from: date)
        return videoDates.contains(key)
    }

    private func previousMonth() {
        displayedMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
    }

    private func nextMonth() {
        displayedMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
    }
}

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasVideo: Bool
    let isCurrentMonth: Bool

    private let calendar = Calendar.current

    var body: some View {
        ZStack {
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.recordingRed.opacity(0.3))
            } else if isToday {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.recordingRed, lineWidth: 1)
            }

            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.system(size: 14, weight: isToday ? .bold : .regular))
                    .foregroundColor(textColor)

                if hasVideo {
                    Circle()
                        .fill(Theme.recordingRed)
                        .frame(width: 5, height: 5)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 5, height: 5)
                }
            }
        }
        .frame(height: 36)
    }

    private var textColor: Color {
        if isSelected {
            return Theme.textPrimary
        } else if !isCurrentMonth {
            return Theme.textSecondary.opacity(0.3)
        } else {
            return Theme.textPrimary
        }
    }
}
