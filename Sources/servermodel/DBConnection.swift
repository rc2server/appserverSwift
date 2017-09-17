//
//  DBConnection.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import Dispatch
import Node
import PostgreSQL

/// These protocols exist to hide FileChangeMomitor from any reference to PostgreSQL. This is necessary to allow unit testing, and decoupling is always a good thing. Subclassing doesn't work since everything in PostgreSQL is final.

public protocol DBNotification {
	var pid: Int { get }
	var channel: String { get }
	var payload: String? { get }
}

extension Connection.Notification: DBNotification {}

public protocol DBConnection {
	func execute(query: String, values: [Node]) throws -> Node
//	func execute(_ query: String, _ binds: [Bind]) throws -> Node
	func close() throws
	func makeListenDispatchSource(toChannel channel: String, queue: DispatchQueue, callback: @escaping (_ note: DBNotification?, _ err: Error?) -> Void) throws -> DispatchSourceRead
}

public struct MockDBNotification: DBNotification {
	public let pid: Int
	public let channel: String
	public let payload: String?
}

public class MockDBConnection: DBConnection {
	public enum MockDBError: String, Error {
		case unimplemented
	}
	public func execute(query: String, values: [Node]) throws -> Node
	{
		throw MockDBError.unimplemented
	}
	
	public func close() throws {
		throw MockDBError.unimplemented
	}
	
	public func makeListenDispatchSource(toChannel channel: String, queue: DispatchQueue, callback: @escaping (DBNotification?, Error?) -> Void) throws -> DispatchSourceRead
	{
		throw MockDBError.unimplemented
	}
}

extension Connection: DBConnection {
	public func execute(query: String, values: [Node] = []) throws -> Node {
		return try execute(query, values)
	}
	
	public func makeListenDispatchSource(toChannel channel: String, queue: DispatchQueue, callback: @escaping (_ note: DBNotification?, _ err: Error?) -> Void) throws -> DispatchSourceRead
	{
		let castCallback = callback as (Connection.Notification?, Error?) -> Void
		return try makeListenDispatchSource(toChannel: channel, queue: queue, callback: castCallback)
	}
}
