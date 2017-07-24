//
//  SessionSocket.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import PerfectWebSockets
import servermodel

class SessionSocket: Hashable {
	let socket: WebSocket
	let user: User
	let settings: AppSettings
	
	init(socket: WebSocket, user: User, settings: AppSettings) {
		self.socket = socket
		self.user = user
		self.settings = settings
	}
	
	var hashValue: Int { return ObjectIdentifier(self).hashValue }
	
	static func == (lhs: SessionSocket, rhs: SessionSocket) -> Bool {
		return lhs.socket == rhs.socket
	}
}
