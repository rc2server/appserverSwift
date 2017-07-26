//
//  Workspace+Node.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import Node
import Rc2Model

public extension Workspace {
	public init(node: Node) throws {
		self.init(id: try node.get("id"), version: try node.get("version"), name: try node.get("name"), userId: try node.get("userid"), projectId: try node.get("projectid"), uniqueId: try node.get("uniqueid"), lastAccess: try node.get("lastaccess"), dateCreated: try node.get("datecreated"))
	}
}
