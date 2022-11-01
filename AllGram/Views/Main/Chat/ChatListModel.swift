//
//  ChatListModel.swift
//  AllGram
//
//  Created by Vladyslav on 18.01.2022.
//

import Foundation
import MatrixSDK

class ChatListModel : ObservableObject {
    @Published var isBusy = false
    
    func moveToFavorites(room: AllgramRoom) {
        let mxRoom = room.room
        let order = room.session.tagOrderToBe(at: 0, from: UInt(NSNotFound), withTag: kMXRoomTagFavourite)!
        isBusy = true
        if nil != mxRoom.accountData.tags?[kMXRoomTagLowPriority] {
            mxRoom.removeTag(kMXRoomTagLowPriority) { response in
                mxRoom.addTag(kMXRoomTagFavourite, withOrder: order) { response in
                    self.isBusy = false
                }
            }
        } else {
            mxRoom.addTag(kMXRoomTagFavourite, withOrder: order) { response in
                self.isBusy = false
            }
        }
    }
    
    func moveToGeneral(room: AllgramRoom) {
        var tagsToDelete = [String]()
        if let tags = room.room.accountData.tags {
            if nil != tags[kMXRoomTagFavourite] {
                tagsToDelete.append(kMXRoomTagFavourite)
            }
            if nil != tags[kMXRoomTagLowPriority] {
                tagsToDelete.append(kMXRoomTagLowPriority)
            }
        }
        guard let tag1 = tagsToDelete.first else { return }
        isBusy = true
        room.room.removeTag(tag1) { response in
            if tagsToDelete.count < 2 {
                self.isBusy = false
                return
            }
            room.room.removeTag(tagsToDelete[1]) { response in
                self.isBusy = false
            }
        }
    }
    func moveToLowPriority(room: AllgramRoom) {
        let mxRoom = room.room
        let order = room.session.tagOrderToBe(at: 0, from: UInt(NSNotFound), withTag: kMXRoomTagLowPriority)!
        isBusy = true
        if nil != mxRoom.accountData.tags?[kMXRoomTagFavourite] {
            mxRoom.removeTag(kMXRoomTagFavourite) { response in
                mxRoom.addTag(kMXRoomTagLowPriority, withOrder: order) { response in
                    self.isBusy = false
                }
            }
        } else {
            mxRoom.addTag(kMXRoomTagLowPriority, withOrder: order) { response in
                self.isBusy = false
            }
        }
    }
    
    
    func isInFavorites(room: AllgramRoom) -> Bool {
        room.summary.dataTypes.contains(.favorited)
    }
    func isInLowPriority(room: AllgramRoom) -> Bool {
        room.summary.dataTypes.contains(.lowPriority)
    }
}
