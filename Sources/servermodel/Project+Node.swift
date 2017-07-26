//
//  Project+Node.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import Node
import Rc2Model

public extension Rc2Model.Project {
	public init(node: Node) throws {
		self.init(id: try node.get("id"), version: try node.get("version"), userId: try node.get("userid"), name: try node.get("name"))
	}
}
