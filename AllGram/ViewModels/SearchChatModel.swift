//
//  SearchChatModel.swift
//  AllGram
//
//  Created by Sergiy Nasinnyk on 01.02.2022.
//

import Foundation

class SearchChatModel : ObservableObject {
    let canBeLongPressed : Bool
    
    @Published var refreshCounter = 0
    
    private var timer = Timer()
    private let oneDayInSeconds : TimeInterval = 24 * 3600
    private var lastDate : Date?
    private var roomToLeave : AllgramRoom?
    
    init(canBeLongPressed: Bool) {
        self.canBeLongPressed = canBeLongPressed
    }
    
    func designateRoomToLeave(offsets: IndexSet, rooms: [AllgramRoom]) -> Bool {
        if let index = offsets.last, index < rooms.count {
            roomToLeave = rooms[index]
            return true
        }
        return false
    }
    
    func nameOfRoomToLeave() -> String {
        guard let summary = roomToLeave?.summary else {
            return ""
        }
        return summary.displayname ?? summary.roomId ?? ""
    }
    
    func leaveRoom() {
        if let mxRoom = roomToLeave?.room {
            mxRoom.mxSession?.leaveRoom(mxRoom.roomId) { _ in }
        }
    }
    
    func resetTimerUsing(lastDate: Date?) {
        if timer.isValid {
            timer.invalidate()
        }
        self.lastDate = lastDate
    
        timer = Timer.scheduledTimer(withTimeInterval: oneDayInSeconds, repeats: true, block: { [weak self] timer in
            guard let self = self else { return }
            self.refreshCounter += 1
            timer.fireDate = self.nextFireDate()
        })
        timer.fireDate = nextFireDate()
    }
    func stopTimer() {
        timer.invalidate()
    }
    
    private func nextFireDate() -> Date {
        // up to the end of day
        let nextDayBeginning = Calendar.current.startOfDay(for: Date(timeIntervalSinceNow: oneDayInSeconds))
        if let secondsNegative = lastDate?.timeIntervalSinceNow, secondsNegative <= 0 {
            let seconds = -secondsNegative
            let deltaT : TimeInterval
            
            if seconds < 60 {
                deltaT = 5
            } else if seconds < 3600 {
                deltaT = 60
            } else if seconds < nextDayBeginning.timeIntervalSinceNow {
                deltaT = 3600
            } else {
                return nextDayBeginning
            }
            return Date(timeIntervalSinceNow: deltaT + 0.5 - seconds.truncatingRemainder(dividingBy: deltaT))
        }
        
        return nextDayBeginning
    }
}
