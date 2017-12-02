//
//  LoginTokenDAO.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import PostgreSQL
import Node
import Rc2Model
import MJLLogger

/// Simple wrapper around contents stored in the authentication token
public struct LoginToken {
	public let id: Int
	public let userId: Int
	
	public init?(_ dict: [String: Any]) {
		guard let inId = dict["token"] as? Int, let inUser = dict["user"] as? Int else { return nil }
		id = inId
		userId = inUser
	}
	
	public init(_ inId: Int, _ inUser: Int)  {
		id = inId
		userId = inUser
	}
	
	public var contents: [String: Any] { return ["token": id, "user": userId] }
}

/// Wrapper for database actions related to login tokens
public final class LoginTokenDAO {
	private let pgdb: PostgreSQL.Database
	
	/// create a DAO
	///
	/// - Parameter database: the database to query
	public init(database: PostgreSQL.Database) {
		pgdb = database
	}
	
	/// create a new login token for a user
	///
	/// - Parameter user: the user to create a token for
	/// - Returns: a new token
	/// - Throws: a .dbError if the sql command fails
	public func createToken(user: User) throws -> LoginToken {
		guard let conn = try? pgdb.makeConnection() else { throw ModelError.failedToOpenConnection }
		var array: [Node]?
		do {
			let result = try conn.execute("insert into logintoken (userId) values ($1) returning id", [user.id])
			 array = result.array
		} catch {
			Log.error("failed to insert logintoken \(error)")
			throw ModelError.dbError
		}
		guard let realarray = array, realarray.count == 1 else { throw ModelError.dbError }
		do {
			return LoginToken(try realarray[0].get("id"), user.id)
		} catch {
			throw ModelError.dbError
		}
	}
	
	/// checks the database to make sure a token is still valid
	///
	/// - Parameter token: the token to check
	/// - Returns: true if the token is still valid
	public func validate(token: LoginToken) -> Bool {
		guard let conn = try? pgdb.makeConnection(),
			let result = try? conn.execute("select * from logintoken where id = $1 and userId = $2 and valid = true", [token.id, token.userId]),
			let array = result.array, array.count == 1
		else {
			return false
		}
		return true
	}
	
	/// invalidate a token so it can't be used again
	///
	/// - Parameter token: the token to invalidate
	/// - Throws: errors from executing sql
	public func invalidate(token: LoginToken) throws {
		let query = "update logintoken set valid = false where id = $1 and userId = $2"
		let conn = try pgdb.makeConnection()
		try conn.execute(query, [token.id, token.userId])
	}
}
