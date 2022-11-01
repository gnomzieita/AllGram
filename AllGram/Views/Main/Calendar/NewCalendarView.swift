//
//  NewCalendarView.swift
//  AllGram
//
//  Created by Alex Pirog on 22.08.2022.
//

import SwiftUI

enum CalendarMode {
    case week, month
}

struct CalendarContainerView: View {
    private let yearFormatter: DateFormatter
    private let monthFormatter: DateFormatter
    private let dayFormatter: DateFormatter
    private let weekDayFormatter: DateFormatter
    private let fullFormatter: DateFormatter

    @Binding private var selectedDate: Date
    @Binding private var updater: Int
    
    @State private var mode = CalendarMode.week
    @State private var showYearPicker = false
    
    private let eventDates: [Date]
    private let allowPastDates: Bool
    private let calendar: Calendar
    private let today: Date
    private let week: [Date]
    
    init(
        selectedDate: Binding<Date>,
        eventDates: [Date],
        allowPastDates: Bool,
        calendar: Calendar = .current,
        updater: Binding<Int> = .constant(0)
    ) {
        self._selectedDate = selectedDate
        self._updater = updater
        self.calendar = calendar
        self.eventDates = eventDates
        self.allowPastDates = allowPastDates
        
        // Helpers
        self.today = calendar.startOfDay(for: Date())
        let weekInterval = calendar.dateInterval(of: .weekOfMonth, for: today.startOfMonth(using: calendar))!
        self.week = calendar.generateDays(for: weekInterval)
        
        // Different date formatters
        self.yearFormatter = DateFormatter(dateFormat: "yyyy", calendar: calendar)
        self.monthFormatter = DateFormatter(dateFormat: "MMMM", calendar: calendar)
        self.dayFormatter = DateFormatter(dateFormat: "d", calendar: calendar)
        self.weekDayFormatter = DateFormatter(dateFormat: "EEEEE", calendar: calendar)
        self.fullFormatter = DateFormatter(dateFormat: "MMMM dd, yyyy", calendar: calendar)
    }

    var body: some View {
        VStack(spacing: 8) {
            // Header
            calendarHeader(for: selectedDate)
                .padding(.horizontal, 8)
            
            // Date/year picker
            if showYearPicker {
                yearPickerView
            } else {
                weekHeader
                calendarView
            }
        }
    }
    
    // MARK: - Header
    
    private func calendarHeader(for date: Date) -> some View {
        HStack {
            // Year picker
            ExpandingHStack(contentPosition: .left()) {
                Button {
                    withAnimation { showYearPicker.toggle() }
                } label: {
                    HStack {
                        Text(yearFormatter.string(from: date))
                            .font(.subheadline)
                            .bold()
                        chevronImage(direction: showYearPicker ? "up" : "down")
                    }
                }
            }
            if showYearPicker {
                Button {
                    withAnimation { showYearPicker = false }
                } label: {
                    Text("Cancel").bold()
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
            } else {
                // Month title
                Text(monthFormatter.string(from: date))
                    .font(.subheadline)
                    .bold()
                // Month switcher
                ExpandingHStack(contentPosition: .right()) {
                    Button {
                        var newDate: Date?
                        switch mode {
                        case .week: newDate = calendar.date(byAdding: .day, value: -7, to: selectedDate)
                        case .month: newDate = calendar.date(byAdding: .month, value: -1, to: selectedDate)
                        }
                        guard let date = newDate else { return }
                        // Do not select past dates when changing week/month
                        if allowPastDates {
                            withAnimation { selectedDate = date }
                        } else {
                            withAnimation { selectedDate = date < today ? today : date }
                        }
                    } label: {
                        chevronImage(direction: "left")
                    }
                    .disabled(disableBack)
                    Button {
                        withAnimation { selectedDate = today }
                    } label: {
                        Text("Today").bold()
                            .font(.subheadline)
                            .foregroundColor(.accentColor)
                    }
                    Button {
                        var newDate: Date?
                        switch mode {
                        case .week: newDate = calendar.date(byAdding: .day, value: 7, to: selectedDate)
                        case .month: newDate = calendar.date(byAdding: .month, value: 1, to: selectedDate)
                        }
                        guard let date = newDate else { return }
                        // Do not select past dates when changing week/month
                        if allowPastDates {
                            withAnimation { selectedDate = date }
                        } else {
                            withAnimation { selectedDate = date < today ? today : date }
                        }
                    } label: {
                        chevronImage(direction: "right")
                    }
                }
            }
        }
    }
    
    private var disableBack: Bool {
        guard !allowPastDates else { return false }
        // Only possible to check future dates if specified
        let sameYear = calendar.component(.year, from: today) == calendar.component(.year, from: selectedDate)
        let sameMonth = calendar.component(.month, from: today) == calendar.component(.month, from: selectedDate)
        let sameWeek = calendar.component(.weekOfMonth, from: today) == calendar.component(.weekOfMonth, from: selectedDate)
        switch mode {
        case .week: return sameYear && sameMonth && sameWeek
        case .month: return sameYear && sameMonth
        }
    }
    
    // Available directions: right, left, up, down
    private func chevronImage(direction: String) -> some View {
        Image(systemName: "chevron.\(direction)")
            .renderingMode(.template)
            .resizable().scaledToFit()
            .frame(width: 14, height: 14)
            .padding(5)
            .foregroundColor(.gray)
    }
    
    // MARK: - Calendar
    
    private var calendarView: some View {
        NewCalendarView(
            mode: mode,
            date: $selectedDate,
            calendar: calendar,
            updater: $updater,
            content: { date in
                // Dates of the month
                calendarDateView(date)
            },
            leading: { date in
                // Dates from previous month
                otherDateView(date)
                    .opacity(mode == .week ? 1 : 0)
            },
            trailing: { date in
                // Dates from next month
                otherDateView(date)
                    .opacity(mode == .week ? 1 : 0)
            },
            header: { date in
                // Header above calendar dates
                EmptyView()
            },
            footer: { date in
                // Footer below calendar dates
                calendarFooter
            }
        )
        .equatable()
    }
    
    @ViewBuilder
    private var weekHeader: some View {
        LazyVGrid(columns: Array(repeating: GridItem(), count: 7)) {
            ForEach(week.prefix(7), id: \.self) { day in
                dateViewPlaceholder
                    .overlay(
                        Text(weekDayFormatter.string(from: day))
                            .font(.caption)
                            .bold()
                    )
            }
        }
        .background(Color(hex: "#F0F0F0"))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    // MARK: - Selecting Year
        
    private var yearPickerView: some View {
        VStack {
            Divider()
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack {
                    let years = makeNextYears(count: 20)
                    ForEach(years, id: \.self) { year in
                        Button {
                            selectedDate = year
                            withAnimation { showYearPicker = false }
                        } label: {
                            if calendar.isDate(selectedDate, equalTo: year, toGranularity: .year) {
                                yearViewPlaceholder
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.accentColor)
                                    )
                                    .overlay(
                                        Text(yearFormatter.string(from: year))
                                            .font(.subheadline)
                                            .foregroundColor(.backColor)
                                    )
                            } else {
                                yearViewPlaceholder
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(Color.gray)
                                    )
                                    .overlay(
                                        Text(yearFormatter.string(from: year))
                                            .font(.subheadline)
                                    )
                            }
                        }
                    }
                }
            }
            .frame(height: 36)
            .padding(.bottom, 6)
        }
    }
    
    // Placeholder for all years to be of same size
    private var yearViewPlaceholder: some View {
        Text("0000")
            .font(.subheadline)
            .foregroundColor(.clear)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
    }
    
    private func makeNextYears(count: Int) -> [Date] {
        // Start with 2021 year and forward
        let startYearComponents = DateComponents(calendar: calendar, year: 2021, month: calendar.component(.month, from: selectedDate), day: calendar.component(.day, from: selectedDate))
        let startYear = calendar.date(from: startYearComponents)!
        var years = [startYear]
        for i in 1...count {
            guard let newYear = calendar.date(byAdding: .year, value: i, to: startYear)
            else { continue }
            years.append(newYear)
        }
        return years
    }
    
    // MARK: - Footer
    
    @ViewBuilder
    private var calendarFooter: some View {
        switch mode {
        case .week:
            Button {
                withAnimation { mode = .month }
            } label: {
                ExpandingHStack {
                    Image(systemName: "chevron.down")
                        .renderingMode(.template)
                        .resizable().scaledToFit()
                        .frame(width: 18)
                        .padding(.vertical, 3)
                        .foregroundColor(.gray)
                }
            }
        case .month:
            Button {
                withAnimation { mode = .week }
            } label: {
                ExpandingHStack {
                    Image(systemName: "chevron.up")
                        .renderingMode(.template)
                        .resizable().scaledToFit()
                        .frame(width: 18)
                        .padding(.vertical, 3)
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    // MARK: - Dates
    
    @ViewBuilder
    private func calendarDateView(_ date: Date) -> some View {
        if date < today && !allowPastDates {
            otherDateView(date)
        } else {
            Button {
                withAnimation { selectedDate = date }
            } label: {
                selectableDateView(date)
            }
        }
    }
    
    // View for past/future days, always greyed out
    private func otherDateView(_ date: Date) -> some View {
        dateViewPlaceholder
            .overlay(
                Text(dayFormatter.string(from: date))
                    .font(dateFont)
                    .foregroundColor(.gray)
            )
            .padding(2)
    }
    
    // View for selectable days, filled when selected
    private func selectableDateView(_ date: Date) -> some View {
        dateViewPlaceholder
            .background(dateBackgroundView(date))
            .overlay(
                Text(dayFormatter.string(from: date))
                    .font(dateFont)
                    .foregroundColor(dateForegroundColor(date))
            )
            .overlay(
                Circle()
                    .foregroundColor(.green)
                    .frame(width: 5, height: 5)
                    .opacity(dateHasEvents(date) ? 1 : 0)
                , alignment: .bottom
            )
            .padding(2)
    }
    
    // Placeholder for all days to be of same size
    private var dateViewPlaceholder: some View {
        Text("00")
            .font(dateFont)
            .lineLimit(1)
            .foregroundColor(.clear)
            .padding(8)
    }
    
    @ViewBuilder
    private func dateBackgroundView(_ date: Date) -> some View {
        if dateIsSelected(date) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor)
        } else {
            EmptyView()
        }
    }
    
    private func dateForegroundColor(_ date: Date) -> Color {
        dateIsSelected(date) ? .backColor : .reverseColor
    }
    
    private let dateFont = Font.subheadline
    
    private func dateHasEvents(_ date: Date) -> Bool {
        guard !dateIsSelected(date) else { return false }
        for eventDate in eventDates {
            if calendar.isDate(date, inSameDayAs: eventDate) {
                return true
            }
        }
        return false
    }
    
    private func dateIsSelected(_ date: Date) -> Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }
}

extension CalendarContainerView: Equatable {
    static func == (lhs: CalendarContainerView, rhs: CalendarContainerView) -> Bool {
        lhs.calendar == rhs.calendar
        && lhs.mode == rhs.mode
        && lhs.showYearPicker == rhs.showYearPicker
        && lhs.selectedDate == rhs.selectedDate
        && lhs.eventDates == rhs.eventDates
    }
}

// MARK: - Component

struct NewCalendarView<Day: View, Leading: View, Trailing: View, Header: View, Footer: View>: View {
    private let mode: CalendarMode
    @Binding private var date: Date
    private var calendar: Calendar
    @Binding private var updater: Int
    private let content: (Date) -> Day
    private let leading: (Date) -> Leading
    private let trailing: (Date) -> Trailing
    private let header: (Date) -> Header
    private let footer: (Date) -> Footer

    init(
        mode: CalendarMode,
        date: Binding<Date>,
        calendar: Calendar,
        updater: Binding<Int>,
        @ViewBuilder content: @escaping (Date) -> Day,
        @ViewBuilder leading: @escaping (Date) -> Leading,
        @ViewBuilder trailing: @escaping (Date) -> Trailing,
        @ViewBuilder header: @escaping (Date) -> Header,
        @ViewBuilder footer: @escaping (Date) -> Footer
    ) {
        self.mode = mode
        self._date = date
        self.calendar = calendar
        self._updater = updater
        self.content = content
        self.leading = leading
        self.trailing = trailing
        self.header = header
        self.footer = footer
    }

    var body: some View {
        let modeCheckDay = checkDay
        let modeGranularity = granularity
        let modeDays = days
        
        return LazyVGrid(columns: Array(repeating: GridItem(), count: 7), spacing: 0) {
            Section {
                ForEach(modeDays, id: \.self) { date in
                    if calendar.isDate(date, equalTo: modeCheckDay, toGranularity: modeGranularity) {
                        content(date)
                    } else {
                        if date < modeCheckDay { leading(date) }
                        else { trailing(date) }
                    }
                }
            } header: {
                header(modeCheckDay)
            } footer: {
                footer(modeCheckDay)
            }
        }
    }
    
    // MARK: -
    
    private var checkDay: Date {
        switch mode {
        case .week: return date.startOfWeek(using: calendar)
        case .month: return date.startOfMonth(using: calendar)
        }
    }
    
    private var granularity: Calendar.Component {
        switch mode {
        case .week: return .weekOfMonth
        case .month: return .month
        }
    }
    
    private var days: [Date] {
        switch mode {
        case .week: return makeWeekDays()
        case .month: return makeMonthDays()
        }
    }
    
    private func makeMonthDays() -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: date),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
              let monthLastWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.end - 1)
        else { return [] }
        let dateInterval = DateInterval(start: monthFirstWeek.start, end: monthLastWeek.end)
        return calendar.generateDays(for: dateInterval)
    }
    
    private func makeWeekDays() -> [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfMonth, for: date)
        else { return [] }
        return calendar.generateDays(for: weekInterval)
    }
}

// MARK: - Conformances

extension NewCalendarView: Equatable {
    public static func == (
        lhs: NewCalendarView<Day, Leading, Trailing, Header, Footer>,
        rhs: NewCalendarView<Day, Leading, Trailing, Header, Footer>
    ) -> Bool {
        // Same calendar, same calendar mode and same selected date
        lhs.calendar == rhs.calendar && lhs.mode == rhs.mode && lhs.date == rhs.date
        // also updaters are same
        && lhs.updater == rhs.updater
    }
}

// MARK: - Helpers

extension Calendar {
    func generateDates(for dateInterval: DateInterval, matching components: DateComponents) -> [Date] {
        var dates = [dateInterval.start]
        enumerateDates(
            startingAfter: dateInterval.start,
            matching: components,
            matchingPolicy: .nextTime
        ) { date, _, stop in
            guard let date = date else { return }
            guard date < dateInterval.end else {
                stop = true
                return
            }
            dates.append(date)
        }
        return dates
    }
    func generateDays(for dateInterval: DateInterval) -> [Date] {
        generateDates(
            for: dateInterval,
            matching: dateComponents([.hour, .minute, .second], from: dateInterval.start)
        )
    }
}

extension Date {
    func startOfWeek(using calendar: Calendar) -> Date {
        calendar.date(
            from: calendar.dateComponents([.year, .month, .weekOfMonth, .weekday], from: self)
        ) ?? self
    }
    func startOfMonth(using calendar: Calendar) -> Date {
        calendar.date(
            from: calendar.dateComponents([.year, .month], from: self)
        ) ?? self
    }
    func startOfYear(using calendar: Calendar) -> Date {
        calendar.date(
            from: calendar.dateComponents([.year], from: self)
        ) ?? self
    }
}

extension DateFormatter {
    convenience init(dateFormat: String, calendar: Calendar) {
        self.init()
        self.dateFormat = dateFormat
        self.calendar = calendar
    }
}
