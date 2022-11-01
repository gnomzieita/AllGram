//
//  MeetingsViewModel.swift
//  AllGram
//
//  Created by Alex Pirog on 31.08.2022.
//

import Foundation
import Combine

class MeetingsViewModel: ObservableObject {
    /// Error that happened during meeting related API call
    @Published var error: Error?
    
    /// Meetings for the whole month.
    /// Automatically updates `eventDates` on change
    @Published private(set) var meetings = [MeetingInfo]() {
        didSet {
            meetingsToEventDates()
            updateSelectedMeetings()
        }
    }
    
    /// All dates that has at least one meeting overlapping it
    @Published private(set) var eventDates = [Date]()

    /// Selected date on the calendar.
    /// Automatically updates `selectedInterval` when needed
    @Published var selectedDate: Date {
        didSet {
            updateSelectedMeetings()
            let oldMonth = oldValue.startOfMonth(using: calendar)
            let newMonth = selectedDate.startOfMonth(using: calendar)
            guard oldMonth != newMonth else { return }
            selectedInterval = calendar.dateInterval(of: .month, for: selectedDate)
        }
    }
    
    /// Interval of the whole month for selected date, fetches meetings on change
    @Published private var selectedInterval: DateInterval? {
        didSet {
            guard let interval = selectedInterval else { return }
            updateMeetings(in: interval, clear: true)
        }
    }
    
    /// All meetings overlapping current selected date.
    /// Updates on `selectedDate` and `meetings` changes
    @Published private(set) var selectedMeetings = [MeetingInfo]()

    let calendar: Calendar

    init(date: Date = Date(), calendar: Calendar = .current) {
        self.calendar = calendar
        self.selectedDate = date
        self.selectedInterval = calendar.dateInterval(of: .month, for: date)
        // Issue update after a delay on new room (as it may be room for meeting)
        NotificationCenter.default.addObserver(self, selector: #selector(updateOnNewRoom), name: .userCreatedRoom, object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        updateCancellable?.cancel()
        updateCancellable = nil
    }
    
    func update() {
        guard let interval = selectedInterval else { return }
        updateMeetings(in: interval, clear: false)
    }
    
    @objc
    private func updateOnNewRoom(_ notification: Notification) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) { [weak self] in
            self?.update()
        }
    }
    
    private var updateCancellable: AnyCancellable?

    private func updateMeetings(in interval: DateInterval, clear: Bool) {
        updateCancellable?.cancel()
        if clear { meetings = [] }
        let accessToken = AuthViewModel.shared.sessionVM!.accessToken
        updateCancellable = NewApiManager.shared.getMeetings(
            startDate: interval.start,
            endDate: interval.end,
            accessToken: accessToken
        )
            .sink { [weak self] completion in
                switch completion {
                case .finished:
                    break
                case .failure(let error):
                    self?.error = error
                }
            } receiveValue: { [weak self] meetings in
                self?.meetings = meetings
            }
    }
    
    private func meetingsToEventDates() {
        var all = [Date]()
        for meeting in meetings {
            let start = meeting.startDate
            let end = meeting.endDate
            all.append(start)
            if !calendar.isDate(start, inSameDayAs: end) {
                all.append(end)
            }
        }
        // Get day starting time for each and remove duplicates
        eventDates = all.map { calendar.startOfDay(for: $0) }.removingDuplicates()
    }
    
    private func updateSelectedMeetings() {
        selectedMeetings = meetings.filter {
            calendar.isDate(selectedDate, inSameDayAs: $0.startDate)
            || calendar.isDate(selectedDate, inSameDayAs: $0.endDate)
        }
    }
}
