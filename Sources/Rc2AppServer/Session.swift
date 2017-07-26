//
//  Session.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import PerfectLib
import Rc2Model
import servermodel

class Session: SessionSocketDelegate {
	
	let workspace: Workspace
	let settings: AppSettings
	private let lockQueue: DispatchQueue
	private(set) var sockets = Set<SessionSocket>()
	/// allows whatever caches sessions to know when this session
	private(set) var lastClientDisconnectTime: Date?
	
	init(workspace: Workspace, settings: AppSettings) {
		self.workspace = workspace
		self.settings = settings
		self.lockQueue = DispatchQueue(label: "workspace \(workspace.id)")
	}
	
	func add(socket: SessionSocket) {
		lockQueue.sync {
			sockets.insert(socket)
			socket.session = self
			lastClientDisconnectTime = nil
		}
	}
	
	func remove(socket: SessionSocket) {
		lockQueue.sync {
			sockets.remove(socket)
			socket.session = nil
			if sockets.count == 0 {
				lastClientDisconnectTime = Date()
			}
		}
	}
	
	func send<T: Encodable>(object: T) throws {
		let data = try settings.encode(object)
		sockets.forEach { $0.send(data: data) { () in } }
	}

	func closed(socket: SessionSocket) {
		remove(socket: socket)
	}
	
	func handle(command: SessionCommand, socket: SessionSocket) {
		Log.logger.info(message: "got command: \(command)", true)
	}

	var hashValue: Int { return ObjectIdentifier(self).hashValue }
	
	static func == (lhs: Session, rhs: Session) -> Bool {
		return lhs.workspace.id == rhs.workspace.id
	}
}
