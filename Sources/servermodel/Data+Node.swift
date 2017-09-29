//
//  Data+Node.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import Node

extension Data: NodeConvertible {
	public init(node: Node) throws {
		switch node.wrapped {
		case .bytes(let inBytes):
			self.init(bytes: inBytes)
		default:
			throw NodeError.unableToConvert(input: node, expectation: "expected byte[] array", path: [])
		}
	}
	
	public func makeNode(in context: Context?) throws -> Node {
		let bytes: [UInt8] = Array(self)
		return Node(.bytes(bytes), in: context)
	}
}

extension StructuredData {
	public var data: Data? {
		return try? Data(node: self, in: nil)
	}
}

