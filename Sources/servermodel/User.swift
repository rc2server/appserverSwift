//
//  User.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import Node

public final class User: PersistentObject {
	public internal(set) var login: String
	public internal(set) var passwordHash: String?
	public internal(set) var firstName: String?
	public internal(set) var lastName: String?
	public internal(set) var email: String
	public internal(set) var isAdmin: Bool = false
	public internal(set) var isEnabled: Bool = true
	
	public required init?(node: Node) throws {
		login = try node.get("login")
		passwordHash = node["passworddata"]?.string
		firstName = node["firstName"]?.string
		lastName = node["lastName"]?.string
		email = try node.get("email")
		isAdmin = try node.get("admin")
		isEnabled = try node.get("enabled")
		try super.init(node: node)
	}
	
	public override func makeNode(in context: Context?) throws -> Node {
		var node = try super.makeNode(in: context)
		try node.set("login", login)
		try node.set("passworddata", passwordHash)
		try node.set("firstName", firstName)
		try node.set("lastName", lastName)
		try node.set("email", email)
		try node.set("admin", isAdmin)
		try node.set("enabled", isEnabled)
		return node
	}
}
