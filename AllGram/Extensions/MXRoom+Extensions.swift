//
//  MXRoom+Extensions.swift
//  AllGram
//
//  Created by Wladislaw Derevianko on 27.09.2021.
//

import Foundation
import MatrixSDK

extension MXRoom {
	var dangerousSyncState : MXRoomState? {
		var state : MXRoomState?
		self.state { roomState in
			state = roomState
		}
		assert(state != nil, "[MXRoom+Sync] syncState failed. Are you sure the state of the room has been already loaded?")
		
		return state
	}
}
