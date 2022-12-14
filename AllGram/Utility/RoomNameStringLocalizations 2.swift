//  Converted to Swift 5.4 by Swiftify v5.4.22271 - https://swiftify.com/
/*
 Copyright 2018 New Vector Ltd

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

/// The `RoomNameStringLocalizations` implements localization strings for `MXRoomNameStringsLocalizable`.

class RoomNameStringLocalizations: NSObject, MXRoomNameStringsLocalizable {
    private(set) var emptyRoom = ""
    private(set) var twoMembers = ""
    private(set) var moreThanTwoMembers = ""

    override init() {
        emptyRoom = "room_displayname_empty_room"//Bundle.mxk_localizedString(forKey: "room_displayname_empty_room")
        twoMembers = "room_displayname_two_members"//Bundle.mxk_localizedString(forKey: "room_displayname_two_members")
        moreThanTwoMembers = "room_displayname_more_than_two_members"//Bundle.mxk_localizedString(forKey: "room_displayname_more_than_two_members")
    }
}
