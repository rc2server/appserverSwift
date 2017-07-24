//
//  Session.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import Rc2Model
import servermodel

class Session {
	let workspace: Workspace
	private(set) var sockets = Set<SessionSocket>()
	
	init(workspace: Workspace) {
		self.workspace = workspace
	}
	
	func add(socket: SessionSocket) {
		sockets.insert(socket)
	}
}
