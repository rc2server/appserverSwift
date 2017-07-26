//
//  User+Node.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import Node
import Rc2Model

public extension User {
	public init(node: Node) throws {
		self.init(id: try node.get("id"), version: try node.get("version"), login: try node.get("login"), email: try node.get("email"), passwordHash: node["passworddata"]?.string, firstName: node["firstName"]?.string, lastName: node["lastName"]?.string, isAdmin: try node.get("admin"), isEnabled: try node.get("enabled"))
	}
//
//	public override func makeNode(in context: Context?) throws -> Node {
//		var node = try super.makeNode(in: context)
//		try node.set("login", login)
//		try node.set("passworddata", passwordHash)
//		try node.set("firstName", firstName)
//		try node.set("lastName", lastName)
//		try node.set("email", email)
//		try node.set("admin", isAdmin)
//		try node.set("enabled", isEnabled)
//		return node
//	}
}
