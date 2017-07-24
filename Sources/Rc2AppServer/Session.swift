//
//  Session.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import Rc2Model
import servermodel

class Session: Hashable {
	let workspace: Workspace
	private(set) var sockets = Set<SessionSocket>()
	
	init(workspace: Workspace) {
		self.workspace = workspace
	}
	
	func add(socket: SessionSocket) {
		sockets.insert(socket)
	}
	
	var hashValue: Int { return ObjectIdentifier(self).hashValue }
	
	static func == (lhs: Session, rhs: Session) -> Bool {
		return lhs.workspace.id == rhs.workspace.id
	}
}
