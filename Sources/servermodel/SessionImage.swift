//
//  SessionImage.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import Node
import Rc2Model

public extension SessionImage {
	public init(node: Node) throws {
		self.init(id: try node.get("id"), sessionId: try node.get("sessionid"), batchId: try node.get("batchid"), name: try node.get("name"), title: try node.get("title"), dateCreated: try node.get("datecreated"), imageData: try node.get("imgdata") as Data)
	}
}
