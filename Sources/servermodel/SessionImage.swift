//
//  SessionImage.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import Node

public final class SessionImage: PersistentObject {
	public internal(set) var sessionId: Int
	public internal(set) var batchId: Int
	public internal(set) var name: String
	public internal(set) var title: String?
	public internal(set) var dateCreated: Date
	public internal(set) var imageData: Data
	
	public required init?(node: Node) throws {
		sessionId = try node.get("sessionid")
		batchId = try node.get("batchid")
		name = try node.get("name")
		title = try node.get("title")
		dateCreated = try node.get("datecreated")
		imageData = try node.get("imgdata")
		try super.init(node: node)
	}
	
	public override func makeNode(in context: Context?) throws -> Node {
		var node = try super.makeNode(in: context)
		try node.set("sessionid", sessionId)
		try node.set("batchid", batchId)
		try node.set("name", name)
		try node.set("title", title)
		try node.set("datecreated", dateCreated)
		try node.set("imgdata", imageData)
		return node
	}
	
}
