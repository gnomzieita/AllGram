//  Converted to Swift 5.4 by Swiftify v5.4.22271 - https://swiftify.com/
/*
 Copyright 2015 OpenMarket Ltd

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import Foundation
import MatrixSDK

/// `QueuedEvent` represents an event waiting to be processed.

class QueuedEvent: NSObject {
    /// The event.
    private(set) var event: MXEvent?
    /// The state of the room when the event has been received.
    private(set) var state: MXRoomState?
    /// The direction of reception. Is it a live event or an event from the history?
    private(set) var direction: MXTimelineDirection?
    /// Tells whether the event is queued during server sync or not.
    var serverSyncEvent = false
    /// Date of the `event`. If event has a valid `originServerTs`, it's converted to a date object, otherwise current date.
    var eventDate: Date? {
        if event?.originServerTs != kMXUndefinedTimestamp {
            return Date(timeIntervalSince1970: TimeInterval(Double(event?.originServerTs ?? 0)) / 1000)
        }

        return Date()
    }

    init(event: MXEvent?, andRoomState state: MXRoomState?, direction: MXTimelineDirection) {
        super.init()
        self.event = event
        self.state = state
        self.direction = direction
    }
}
