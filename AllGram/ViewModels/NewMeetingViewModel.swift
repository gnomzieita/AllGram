//
//  NewMeetingViewModel.swift
//  AllGram
//
//  Created by Sergiy Nasinnyk on 25.01.2022.
//

import Foundation
import Combine
import MatrixSDK
import SwiftUI

class NewMeetingViewModel: SearcherForUsers {
    @Published var savingInProgress = false
    
    @Published var errorMessage: String?
    
    @Published var meetingName: String = ""
    @Published var users = [UserInfo]()
    @Published var allDay: Bool = false
    @Published var meetingDate: Date
    @Published var startTime: Date {
        didSet {
            // Move end time forwards if needed (interval < 15 minutes)
            let difference = (endTime.timeIntervalSinceReferenceDate - startTime.timeIntervalSinceReferenceDate) / .minute
            if  difference < 15 {
                endTime = startTime.advanced(by: .minute * 15)
            }
        }
    }
    @Published var endTime: Date {
        didSet {
            // Move start time backwards if needed (interval < 15 minutes)
            let difference = (endTime.timeIntervalSinceReferenceDate - startTime.timeIntervalSinceReferenceDate) / .minute
            if  difference < 15 {
                startTime = endTime.advanced(by: -.minute * 15)
            }
        }
    }
    @Published var repeatOption = MeetingFrequency.never
    @Published var meetingDescription: String = ""
    
    // Symbol codes: 005c = \ , 201d = "
    let prohibitedSymbols = ["/",":","*","?",">","<","|","\u{005c}","\u{201d}"]
    
    var hasProhibitedSymbols: Bool {
        for symbol in prohibitedSymbols {
            if meetingName.contains(symbol) {
                return false
            }
        }
        return true
    }
    
    override init(session: MXSession) {
        let day = Date()
        meetingDate = day
        startTime = day
        endTime = day.addingTimeInterval(.hour)
        
        super.init(session: session)
    }
    
    private var cancellableSet = Set<AnyCancellable>()
    
    deinit {
        cancellableSet.removeAll()
    }
    
    enum MeetingError: Error, LocalizedError {
        case inCreatingProcess
        case noName
        case noParticipants
        case endBeforeStart
        case passedStart
        
        public var errorDescription: String? {
            switch self {
            case .inCreatingProcess:
                return NSLocalizedString(
                    "Already in process of creating a meeting.",
                    comment: "inCreatingProcess"
                )
            case .noName:
                return NSLocalizedString(
                    "Invalid meeting name.",
                    comment: "noName"
                )
            case .noParticipants:
                return NSLocalizedString(
                    "Already in process of creating a meeting.",
                    comment: "noParticipants"
                )
            case .endBeforeStart:
                return NSLocalizedString(
                    "End time can't be earlier than start time.",
                    comment: "endBeforeStart"
                )
            case .passedStart:
                return NSLocalizedString(
                    "Start time should be in the future.",
                    comment: "passedStart"
                )
            }
        }
    }
    
    func createMeeting(instant: Bool, completion: @escaping (Result<String, Error>) -> Void) {
        // Only one creation process at a time
        guard !savingInProgress else {
            completion(.failure(MeetingError.inCreatingProcess))
            return
        }
        savingInProgress = true
        
        // Trim prohibited symbols and check name
        var roomName = meetingName
        for symbol in prohibitedSymbols {
            roomName = roomName.replacingOccurrences(of: symbol, with: "")
        }
        guard roomName.hasContent else {
            savingInProgress = false
            completion(.failure(MeetingError.noName))
            return
        }

        // Check participants count
        let participants = users.map { $0.id }
        guard !participants.isEmpty else {
            savingInProgress = false
            completion(.failure(MeetingError.noParticipants))
            return
        }
        
        var start = Date()
        var end = start.advanced(by: .hour)
        
        // Validate start/end dates for scheduled
        // or use predefined ones for instant
        if !instant {
            if allDay {
                // Add 1 minute to the beginning of the day
                start = Calendar.current.startOfDay(for: meetingDate).advanced(by: .minute)
                // Add a full day and subtract 2 minutes to the start
                end = Calendar.current.date(byAdding: .day, value: 1, to: start)!.advanced(by: -.minute * 2)
            } else {
                // Merge day and time values
                let dateComponents = Calendar.current.dateComponents([.year, .month, .day], from: meetingDate)
                let startTimeComponents = Calendar.current.dateComponents([.hour, .minute, .second], from: startTime)
                let endTimeComponents = Calendar.current.dateComponents([.hour, .minute, .second], from: endTime)
                
                var startComponents = DateComponents()
                startComponents.year = dateComponents.year ?? 0
                startComponents.month = dateComponents.month ?? 0
                startComponents.day = dateComponents.day ?? 0
                startComponents.hour = startTimeComponents.hour ?? 0
                startComponents.minute = startTimeComponents.minute ?? 0
                startComponents.second = startTimeComponents.second ?? 0
                
                var endComponents = DateComponents()
                endComponents.year = dateComponents.year ?? 0
                endComponents.month = dateComponents.month ?? 0
                endComponents.day = dateComponents.day ?? 0
                endComponents.hour = endTimeComponents.hour ?? 0
                endComponents.minute = endTimeComponents.minute ?? 0
                endComponents.second = endTimeComponents.second ?? 0
                
                start = Calendar.current.date(from: startComponents)!
                end = Calendar.current.date(from: endComponents)!
            }
            
            // Ensure start date < end date
            guard start < end else {
                savingInProgress = false
                completion(.failure(MeetingError.endBeforeStart))
                return
            }
            
            // Ensure start is in the future (or just less then a minute is the past)
            let distance = Date().timeIntervalSince1970 - start.timeIntervalSince1970
            guard distance > -.minute else {
                savingInProgress = false
                completion(.failure(MeetingError.passedStart))
                return
            }
        }
        
        let frequency = instant ? .never : repeatOption
        let accessToken = mxSession.credentials.accessToken!
        
        // Create room for the meeting first
        ApiManager.shared.createMeetingRoom(meetingName: roomName, userIDList: participants, accessToken: accessToken)
            .sink { [weak self] roomCompletion in
                switch roomCompletion {
                case .failure(let error):
                    self?.savingInProgress = false
                    completion(.failure(error))
                case .finished:
                    break
                }
            } receiveValue: { [unowned self] response in
                NotificationCenter.default.post(name: .userCreatedRoom, object: nil)
                
                let roomID = response.roomID
                // We are sure this is a meeting
                UserDefaults.group.setStoredType(for: roomID, isChat: true, isMeeting: true, forSure: true)
                // Do the update again to ensure correct state
                let newRoom = AuthViewModel.shared.sessionVM?.rooms.first(where: { $0.roomId == roomID })
                newRoom?.checkMeetingState()
                
                // Create event
                NewApiManager.shared.createMeetingEvent(eventName: roomName, startDate: start, endDate: end, frequency: frequency, userIDList: participants, roomID: roomID, accessToken: accessToken)
                    .sink { [weak self] eventCompletion in
                        switch eventCompletion {
                        case .failure(let error):
                            self?.savingInProgress = false
                            completion(.failure(error))
                        case .finished:
                            break
                        }
                    } receiveValue: { [weak self] response in
                        self?.savingInProgress = false
                        completion(.success(roomID))
                    }.store(in: &self.cancellableSet)
            }.store(in: &cancellableSet)
    }
}
