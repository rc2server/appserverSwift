//
//  PersistentObject.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import Node

open class PersistentObject: NodeRepresentable {
	public internal(set) var id: Int
	public internal(set) var version: Int
	
	public required init?(node: Node) throws {
		self.id = try node.get("id")
		self.version = try node.get("version")
	}
	
	public func makeNode(in context: Context?) throws -> Node {
		var node = Node(context)
		try node.set("id", id)
		try node.set("version", version)
		return node
	}
	
}
