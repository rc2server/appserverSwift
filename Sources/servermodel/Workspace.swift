//
//  Workspace.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import Node

public final class Workspace: PersistentObject {
	public internal(set) var name: String
	public internal(set) var userId: Int
	public internal(set) var projectId: Int
	public internal(set) var uniqueId: String
	public internal(set) var lastAccess: Date
	public internal(set) var dateCreated: Date
	
	public required init?(node: Node) throws {
		name = try node.get("name")
		userId = try node.get("userid")
		projectId = try node.get("projectid")
		uniqueId = try node.get("uniqueid")
		lastAccess = try node.get("lastaccess")
		dateCreated = try node.get("datecreated")
		try super.init(node: node)
	}
	
	public override func makeNode(in context: Context?) throws -> Node {
		var node = try super.makeNode(in: context)
		try node.set("name", name)
		try node.set("userId", userId)
		try node.set("projectid", projectId)
		try node.set("uniqueId", uniqueId)
		try node.set("lastaccess", lastAccess)
		try node.set("datecreated", dateCreated)
		return node
	}
	
}
