//
//  Rc2DAO.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import PostgreSQL
import Node
import Rc2Model

open class Rc2DAO {
	let pgdb: PostgreSQL.Database
	// queue is used by internal methods all database calls evenetually use
	let queue: DispatchQueue
	
	public init(host: String, user: String, database: String) throws {
		queue = DispatchQueue(label: "database serial queue")
		pgdb = try PostgreSQL.Database(hostname: host, database: database, user: user, password: "")
	}
	
	public func createTokenDAO() -> LoginTokenDAO {
		return LoginTokenDAO(database: pgdb)
	}
	
	//MARK: - access methods
	/// get user with specified id
	///
	/// - Parameters:
	///   - id: the desired user's id
	///   - connection: optional database connection
	/// - Returns: user with specified id
	/// - Throws: .duplicate if more than one row in database matched, Node errors if problem parsing results
	public func getUser(id: Int, connection: Connection? = nil) throws -> User? {
		guard let user = try User(node: getSingleRow(connection, tableName: "rcuser", keyName: "id", keyValue: Node(integerLiteral: id)))
			else { return nil }
		return user
	}
	
	/// get user with specified id
	///
	/// - Parameters:
	///   - login: the desired user's login
	///   - connection: optional database connection
	/// - Returns: user with specified login
	/// - Throws: .duplicate if more than one row in database matched, Node errors if problem parsing results
	public func getUser(login: String, connection: Connection? = nil) throws -> User? {
		guard let user = try User(node: getSingleRow(connection, tableName: "rcuser", keyName: "login", keyValue: Node(stringLiteral: login)))
			else { return nil }
		return user
	}
	
	/// gets the user with the specified login and password. Returns nil if no user matches.
	///
	/// - Parameters:
	///   - login: user's login
	///   - password: user's password
	///   - connection: optional database connection
	/// - Returns: user if the login/password are valid, nil if user not found
	/// - Throws: node errors 
	public func getUser(login: String, password: String, connection: Connection? = nil) throws -> User? {
		let conn = connection == nil ? try self.pgdb.makeConnection() : connection!
		var query = "select * from rcuser where login = $1"
		var data = [login]
		if password.characters.count == 0 {
			query += " and passworddata IS NULL"
		} else {
			query += " and passworddata = crypt($2, passworddata)"
			data.append(password)
		}
		let result = try conn.execute(query, data)
		guard let array = result.array, array.count == 1 else {
			return nil
		}
		return try User(node: array[0])
	}
	
	/// get project with specific id
	///
	/// - Parameters:
	///   - id: id of the project
	///   - connection: optional database connection
	/// - Returns: project with id of id
	/// - Throws: .duplicate if more than one row in database matched, Node errors if problem parsing results
	public func getProject(id: Int, connection: Connection? = nil) throws -> Project? {
		guard let project = try Project(node: getSingleRow(tableName: "rcproject", keyName: "id", keyValue: Node(integerLiteral: id)))
			else { return nil }
		return project
	}
	
	/// get projects owned by specified user
	///
	/// - Parameters:
	///   - ownedBy: user whose projects should be fetched
	///   - connection: optional database connection
	/// - Returns: array of projects
	/// - Throws: .duplicate if more than one row in database matched, Node errors if problem parsing results
	public func getProjects(ownedBy: User, connection: Connection? = nil) throws -> [Project] {
		let projectNodes = try getRows(tableName: "rcproject", keyName: "userId", keyValue: Node(integerLiteral: ownedBy.id))
		return try projectNodes.flatMap { try Project(node: $0) }
	}
	
	/// get workspace with specific id
	///
	/// - Parameters:
	///   - id: id of the workspace
	///   - connection: optional database connection
	/// - Returns: workspace with id of id
	/// - Throws: .duplicate if more than one row in database matched, Node errors if problem parsing results
	public func getWorkspace(id: Int, connection: Connection? = nil) throws -> Workspace? {
		guard let wspace = try Workspace(node: getSingleRow(tableName: "rcworkspace", keyName: "id", keyValue: Node(integerLiteral: id)))
			else { return nil }
		return wspace
	}
	
	/// gets workspaces belonging to a project
	///
	/// - Parameters:
	///   - project: a project
	///   - connection: optional database connection
	/// - Returns: array of workspaces
	/// - Throws: .duplicate if more than one row in database matched, Node errors if problem parsing results
	public func getWorkspaces(project: Project, connection: Connection? = nil) throws -> [Workspace] {
		let nodes = try getRows(tableName: "rcworkspace", keyName: "projectId", keyValue: Node(integerLiteral: project.id))
		return try nodes.flatMap { try Workspace(node: $0) }
	}
	
	/// get file with specific id
	///
	/// - Parameters:
	///   - id: id of the file
	///   - connection: optional database connection
	/// - Returns: file with id
	/// - Throws: .duplicate if more than one row in database matched, Node errors if problem parsing results
	public func getFile(id: Int, connection: Connection? = nil) throws -> File? {
		guard let file = try File(node: getSingleRow(tableName: "rcfile", keyName: "id", keyValue: Node(integerLiteral: id)))
			else { return nil }
		return file
	}
	
	/// gets files belonging to a workspace
	///
	/// - Parameters:
	///   - workspace: a workspace
	///   - connection: optional database connection
	/// - Returns: array of files
	/// - Throws: .duplicate if more than one row in database matched, Node errors if problem parsing results
	public func getFiles(workspace: Workspace, connection: Connection? = nil) throws -> [File] {
		let nodes = try getRows(tableName: "rcfile", keyName: "wspaceid", keyValue: Node(integerLiteral: workspace.id))
		return try nodes.flatMap { try File(node: $0) }
	}
	
	/// gets the contents of a file
	///
	/// - Parameters:
	///   - fileId: id of file
	///   - connection: optional database connection
	/// - Returns: contents of file
	/// - Throws: .duplicate if more than one row in database matched, Node errors if problem parsing results
	public func getFileData(fileId: Int, connection: Connection? = nil) throws -> Data {
		let result = try getSingleRow(tableName: "rcfiledata", keyName: "id", keyValue: try Node(node: fileId))
		return try result.get("bindata")
	}
	
	
	//MARK: - private methods
	private func getSingleRow(_ connection: Connection? = nil, tableName: String, keyName: String, keyValue: Node) throws -> Node
	{
		var finalResults: Node!
		try queue.sync { () throws -> Void in
			let conn = connection == nil ? try self.pgdb.makeConnection() : connection!
			let result = try conn.execute("select * from \(tableName) where \(keyName) = $1", [keyValue])
			guard let array = result.array, array.count == 1 else {
				throw ModelError.duplicateObject
			}
			finalResults = array[0]
		}
		return finalResults
	}
	
	private func getRows(_ connection: Connection? = nil, tableName: String, keyName: String, keyValue: Node) throws -> [Node]
	{
		var finalResults: [Node] = []
		try queue.sync  { () throws -> Void in
			let conn = connection == nil ? try self.pgdb.makeConnection() : connection!
			let result = try conn.execute("select * from \(tableName) where \(keyName) = $1", [keyValue])
			guard let array = result.array, array.count > 0 else {
				return
			}
			finalResults = array
		}
		return finalResults
	}
}
