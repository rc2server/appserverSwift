//
//  SessionSocket.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import PerfectWebSockets
import servermodel

protocol SessionSocketDelegate {
	func socketClosed(_ socket: SessionSocket)
}

class SessionSocket: Hashable {
	let socket: WebSocket
	let user: User
	let settings: AppSettings
	let delegate: SessionSocketDelegate
	weak var session: Session?
	
	init(socket: WebSocket, user: User, settings: AppSettings, delegate: SessionSocketDelegate) {
		self.socket = socket
		self.user = user
		self.settings = settings
		self.delegate = delegate
	}
	
	var hashValue: Int { return ObjectIdentifier(self).hashValue }
	
	func start() {
		
	}
	
	static func == (lhs: SessionSocket, rhs: SessionSocket) -> Bool {
		return lhs.socket == rhs.socket
	}
}
