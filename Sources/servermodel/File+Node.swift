//
//  File+Node.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import Node
import Rc2Model

public extension File {
	public init(node: Node) throws {
		self.init(id: try node.get("id"), wspaceId: try node.get("wspaceid"), name: try node.get("name"), version: try node.get("version"), dateCreated: try node.get("datecreated"), lastModified: try node.get("lastmodified"), fileSize: try node.get("size"))
	}
//
//	public override func makeNode(in context: Context?) throws -> Node {
//		var node = try super.makeNode(in: context)
//		try node.set("name", name)
//		try node.set("wspaceid", workspaceId)
//		try node.set("filesize", size)
//		try node.set("datecreated", dateCreated)
//		try node.set("lastmodified", lastModified)
//		return node
//	}
//
}
