//
//  File.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import Node

public final class File: PersistentObject {
	public internal(set) var workspaceId: Int
	public internal(set) var name: String
	public internal(set) var size: Int
	public internal(set) var dateCreated: Date
	public internal(set) var lastModified: Date
	
	public required init?(node: Node) throws {
		name = try node.get("name")
		workspaceId = try node.get("wspaceid")
		size = try node.get("filesize")
		dateCreated = try node.get("datecreated")
		lastModified = try node.get("lastmodified")
		try super.init(node: node)
	}
	
	public override func makeNode(in context: Context?) throws -> Node {
		var node = try super.makeNode(in: context)
		try node.set("name", name)
		try node.set("wspaceid", workspaceId)
		try node.set("filesize", size)
		try node.set("datecreated", dateCreated)
		try node.set("lastmodified", lastModified)
		return node
	}
	
}
