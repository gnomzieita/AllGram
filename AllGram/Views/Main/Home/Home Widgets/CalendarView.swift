//
//  CalendarView.swift
//  AllGram
//
//  Created by Oleksandr Pyroh on 15.12.2021.
//

import SwiftUI

// MARK: - Calendar Widget

struct CalendarView: View {
    
    @ObservedObject var authViewModel = AuthViewModel.shared
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }
    
    private var year: DateInterval {
        let startDate = calendar.startOfDay(for: Date())
        let endDate = calendar.date(byAdding: .year, value: 1, to: Date())!
        let interval = DateInterval(start: startDate, end: endDate)
        return interval
    }
    
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    
    var calendarStyle: CalendarStyle {
        return CalendarStyle(inactiveColor: .gray, activeColor: colorScheme == .dark ? .white : .black, selectedColor: .accentColor)
    }
    
    let onMeetingTap: (_ roomId: String) -> Void
    
    var body: some View {
        GeometryReader { geometryProxy in
            ZStack {
                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    .foregroundColor(Color("bgColor") )
                    .padding(.bottom, Constants.textPadding)
                    .shadow(radius: 2)
                VStack {
                    HStack(spacing: 10) {
                        MeetingsView(selectedDate: $selectedDate, onMeetingTap: onMeetingTap)
                            .frame(width: geometryProxy.size.width * 0.4, height: geometryProxy.size.height, alignment: .topLeading)
                        
                        ZCalendarView(interval: year, style: calendarStyle, selectedDate: $selectedDate, calendar: calendar)
                    }
                    .padding(.vertical, Constants.cornerRadius)
                    Text("Calendar")
                        .foregroundColor(.white)
                        .font(.system(size: Constants.fontSize))
                        .shadow(radius: 2)
                }
            }
        }
    }
    
    struct Constants {
        static let cornerRadius: CGFloat = 16
        static let textPadding: CGFloat = 30
        static let fontSize: CGFloat = 14
    }
    
}

struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ZStack {
                Image("homeBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                CalendarView(onMeetingTap: { _ in })
                    .colorScheme(.dark)
                    .frame(maxHeight: 210)
                    .padding(.horizontal, 16)
            }
            ZStack {
                Image("homeBackground")
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                CalendarView(onMeetingTap: { _ in })
                    .colorScheme(.light)
                    .frame(maxHeight: 210)
                    .padding(.horizontal, 16)
            }
        }
    }
}
