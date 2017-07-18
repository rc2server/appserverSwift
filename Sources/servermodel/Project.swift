//
//  Project.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import Node

public final class Project: PersistentObject {
	public internal(set) var name: String
	public internal(set) var userId: Int
	
	public required init?(node: Node) throws {
		name = try node.get("name")
		userId = try node.get("userid")
		try super.init(node: node)
	}
	
	public override func makeNode(in context: Context?) throws -> Node {
		var node = try super.makeNode(in: context)
		try node.set("name", name)
		try node.set("userId", userId)
		return node
	}
	
}
