//
//  MeetingsWidgetViewModel.swift
//  AllGram
//
//  Created by Sergiy Nasinnyk on 20.01.2022.
//

import Foundation
import Combine
import SwiftUI

class MeetingsWidgetViewModel: ObservableObject {
    
    private var cancellables = Set<AnyCancellable>()
    
    @Published var meetingsDate: Date {
        didSet { updateMeetings() }
    }
    
    @Published var meetings: [MeetingInfo] = []
    
    let accessToken: String
    
    init(accessToken: String, meetingsDate: Date) {
        self.accessToken = accessToken
        self.meetingsDate = meetingsDate
    }
    
    func updateMeetings() {
        let startDate = Calendar.current.startOfDay(for: meetingsDate)
        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: startDate)
        guard let endDate = endDate else {
            withAnimation {
                meetings = []
            }
            return
        }
        NewApiManager.shared.getMeetings(startDate: startDate, endDate: endDate, accessToken: accessToken)
            .sink { completion in

            } receiveValue: { [weak self] meetings in
                withAnimation {
                    var fixedColorMeetings = [MeetingInfo]()
//                    for meeting in meetings {
//                        var mutatingMeeting = meeting
//                        // Keep previous color for the meeting
//                        if let color = self?.meetings.first(where: { $0.id == mutatingMeeting.id })?.color {
//                            mutatingMeeting.setColor(color)
//                        }
//                        fixedColorMeetings.append(mutatingMeeting)
//                    }
                    self?.meetings = fixedColorMeetings
                }
            }.store(in: &cancellables)
    }
}
