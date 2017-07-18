//
//  SessionRecord.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import Node

public final class SessionRecord: PersistentObject {
	public internal(set) var workspaceId: Int
	public internal(set) var startDate: Date
	public internal(set) var endDate: Date?
	
	public required init?(node: Node) throws {
		workspaceId = try node.get("wspaceid")
		startDate = try node.get("startdate")
		endDate = try node.get("enddate")
		try super.init(node: node)
	}
	
	public override func makeNode(in context: Context?) throws -> Node {
		var node = try super.makeNode(in: context)
		try node.set("wspaceid", workspaceId)
		try node.set("startdate", startDate)
		try node.set("enddate", endDate)
		return node
	}
	
}
