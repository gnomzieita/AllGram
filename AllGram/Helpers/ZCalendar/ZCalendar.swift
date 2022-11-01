//
//  Calendar.swift
//  AllGram
//
//  Created by Sergiy Nasinnyk on 18.01.2022.
//

import SwiftUI

fileprivate extension DateFormatter {
    static var month: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter
    }
    
    static var year: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter
    }
    
    static var monthAndYear: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }
}

fileprivate extension Calendar {
    func sortedWeekdaySymbols(weekdaySymbols: [String]) -> [String] {
        return Array(weekdaySymbols[self.firstWeekday-1..<weekdaySymbols.count]) + weekdaySymbols[0..<self.firstWeekday-1]
    }
    
    func generateDates(
        inside interval: DateInterval,
        matching components: DateComponents
    ) -> [Date] {
        var dates: [Date] = []
        dates.append(interval.start)
        
        enumerateDates(
            startingAfter: interval.start,
            matching: components,
            matchingPolicy: .nextTime
        ) { date, _, stop in
            if let date = date {
                if date < interval.end {
                    dates.append(date)
                } else {
                    stop = true
                }
            }
        }
        
        return dates
    }
}

struct ZWeekView: View {
    
    let week: Date
    
    let style: CalendarStyle
    
    let activeDates: DateInterval
    
    var selectedDate: Binding<Date>
    
    let calendar: Calendar
    
    init(week: Date, style: CalendarStyle, activeDates: DateInterval, selectedDate: Binding<Date>, calendar: Calendar = Calendar.current) {
        self.week = week
        self.style = style
        self.activeDates = activeDates
        self.selectedDate = selectedDate
        self.calendar = calendar
    }
    
    private var days: [Date] {
        guard
            let weekInterval = calendar.dateInterval(of: .weekOfYear, for: week)
        else { return [] }
        return calendar.generateDates(
            inside: weekInterval,
            matching: DateComponents(hour: 0, minute: 0, second: 0)
        )
    }
    
    private func getColor(for date: Date) -> Color{
        if activeDates.contains(date){
            if calendar.compare(date, to: selectedDate.wrappedValue, toGranularity: .day) == .orderedSame {
                return style.selectedColor
            } else {
                return style.activeColor
            }
        } else {
            return style.inactiveColor
        }
    }
    
    private func isDateSelected(date: Date) -> Bool{
        calendar.compare(date, to: selectedDate.wrappedValue, toGranularity: .day) == .orderedSame
    }
    
    private func getContent(for date: Date) -> some View {
        HStack{
            Button {
                if activeDates.contains(date){
                    selectedDate.wrappedValue = date
                }
            } label: {
                Text("30")
                    .fontWeight(.bold)
                    //.font(.system(size: 500))
                    .lineLimit(1)
                    //.minimumScaleFactor(0.01)
                    .hidden()
                    .overlay(
                        Text(String(calendar.component(.day, from: date)))
                            .foregroundColor(getColor(for: date))
                            .fontWeight(isDateSelected(date: date) ? .bold : .regular)
                            .font(.system(size: 500))
                            .minimumScaleFactor(0.01)
                    )
            }
            Spacer()
        }
    }
    
    var body: some View {
        HStack {
            ForEach(days, id: \.self) { date in
                HStack {
                    if calendar.isDate(self.week, equalTo: date, toGranularity: .month) {
                        self.getContent(for: date)
                    } else {
                        self.getContent(for: date).hidden()
                    }
                }
            }
        }
    }
}

struct ZMonthView: View {
    
    let month: Date
    let showHeader: Bool
    let showWeekdaysHeader: Bool
    
    let style: CalendarStyle
    
    let activeDates: DateInterval
    var selectedDate: Binding<Date>
    
    let calendar: Calendar
    
    init(
        month: Date,
        showHeader: Bool = true,
        showWeekdaysHeader: Bool = true,
        style: CalendarStyle,
        activeDates: DateInterval,
        selectedDate: Binding<Date>,
        calendar: Calendar = Calendar.current
    ) {
        self.month = month
        self.showHeader = showHeader
        self.showWeekdaysHeader = showWeekdaysHeader
        self.style = style
        self.activeDates = activeDates
        self.selectedDate = selectedDate
        self.calendar = calendar
    }
    
    private var weeks: [Date] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: month)
        else { return [] }
        return calendar.generateDates(
            inside: monthInterval,
            matching: DateComponents(hour: 0, minute: 0, second: 0, weekday: calendar.firstWeekday)
        )
    }
    
    private var header: some View {
        let components = calendar.dateComponents([.year, .month], from: month)
        let dcStartDay = calendar.dateComponents([.year, .month], from: calendar.startOfDay(for: activeDates.start))
        return HStack{
            Text(calendar.standaloneMonthSymbols[components.month! - 1].capitalized)
                .font(.title)
            Spacer()
            if components.month == 1 || (components.month == dcStartDay.month && components.year == calendar.component(.year, from: Date())){
                Text(DateFormatter.year.string(from: month))
                    .font(.title)
            }
        }
        .padding(.trailing, 16)
    }
    
    private var weekdaysHeader: some View {
        HStack {
            ForEach(calendar.sortedWeekdaySymbols(weekdaySymbols: calendar.veryShortWeekdaySymbols), id: \.self) { weekdaySymbol in
                HStack {
                    Text("W")
                        .fontWeight(.bold)
                        .font(.system(size: 400))
                        .lineLimit(1)
                        .minimumScaleFactor(0.03)
                        .hidden()
                        .overlay(
                            Text(weekdaySymbol)
                                .foregroundColor(style.activeColor)
                                .font(.system(size: 400))
                                .minimumScaleFactor(0.03)
                                
                        )
                    Spacer()
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 3) {
            if showHeader {
                header
            }
            if showWeekdaysHeader {
                weekdaysHeader
            }
            
            ForEach(weeks, id: \.self) { week in
                ZWeekView(week: week, style: style, activeDates: activeDates, selectedDate: selectedDate, calendar: calendar)
            }
            Spacer()
        }
    }
}

struct ZCalendarView: View {
    
    let interval: DateInterval
    
    let style: CalendarStyle
    
    var selectedDate: Binding<Date>
    
    let calendar: Calendar
    
    init(interval: DateInterval, style: CalendarStyle, selectedDate: Binding<Date>, calendar: Calendar = Calendar.current) {
        self.interval = interval
        self.style = style
        self.selectedDate = selectedDate
        self.calendar = calendar
    }
    
    private var months: [Date] {
        calendar.generateDates(
            inside: interval,
            matching: DateComponents(day: 1, hour: 0, minute: 0, second: 0)
        )
    }
    
    
    
    var body: some View {
        GeometryReader{ geometry in
            ScrollView(.horizontal){
                LazyHStack{
                    TabView{
                        ForEach(months, id: \.self) { month in
                            VStack{
                                ZMonthView(month: month, style: style, activeDates: interval, selectedDate: selectedDate, calendar: calendar)
                                Spacer()
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                }
            }
        }
    }
}

struct CalendarStyle{
    var inactiveColor: Color
    var activeColor: Color
    var selectedColor: Color
}


struct ZCalendarView_Previews: PreviewProvider {
    static var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 1
        return calendar
    }
    
    private static var year: DateInterval {
        let startDate = calendar.date(byAdding: .day, value: -1, to: Date())!
        let endDate = calendar.date(byAdding: .year, value: 1, to: Date())!
        let interval = DateInterval(start: startDate, end: endDate)
        return interval
    }
    
    @State private static var selectedDate = Date()
    
    private static var darkCalendarStyle: CalendarStyle {
        return CalendarStyle(inactiveColor: .gray, activeColor: .white, selectedColor: .accentColor)
    }
    
    private static var lightCalendarStyle: CalendarStyle {
        return CalendarStyle(inactiveColor: .gray, activeColor: .black, selectedColor: .accentColor)
    }
    
    static var previews: some View {
        Group{
            ZCalendarView(interval: year, style: darkCalendarStyle, selectedDate: $selectedDate)
                .preferredColorScheme(.dark)
            ZCalendarView(interval: year, style: lightCalendarStyle, selectedDate: $selectedDate)
        }
    }
}
