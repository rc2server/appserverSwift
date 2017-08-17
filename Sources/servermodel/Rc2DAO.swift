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
	enum DBError: Error {
		case queryFailed
	}
	
	private(set) var pgdb: PostgreSQL.Database?
	// queue is used by internal methods all database calls evenetually use
	let queue: DispatchQueue
	
	public init() {
		queue = DispatchQueue(label: "database serial queue")
	}
	
	public func connect(host: String, user: String, database: String) throws {
		precondition(pgdb == nil)
		pgdb = try PostgreSQL.Database(hostname: host, database: database, user: user, password: "")
	}
	
	public func createTokenDAO() -> LoginTokenDAO {
		guard let pgdb = self.pgdb else { fatalError("Rc2DAO accessed without connection") }
		return LoginTokenDAO(database: pgdb)
	}
	
	//MARK: - access methods
	/// Returns bulk info about a user to return to a client on successful connection
	///
	/// - Parameter user: the user who's info should be returned
	/// - Returns: the requested user info
	/// - Throws: any errors from communicating with the database server
	public func getUserInfo(user: User) throws -> BulkUserInfo {
		let projects = try getProjects(ownedBy: user)
		var wspaceDict = [Int: [Workspace]]()
		var fileDict = [Int: [File]]()
		// load workspaces
		let wsNodes = try getRows(query: "select w.* from rcproject p join rcworkspace w on w.projectid = p.id  where p.userid = \(user.id)")
		projects.forEach { wspaceDict[$0.id] = [] }
		try wsNodes.forEach {
			let wspace = try Workspace(node: $0)
			wspaceDict[wspace.projectId]!.append(wspace)
			fileDict[wspace.id] = []
		}
		// load files
		let fileNodes = try getRows(query: "select f.* from rcproject p join rcworkspace w on w.projectid = p.id join rcfile f on f.wspaceid = w.id  where p.userid = \(user.id)")
		try fileNodes.forEach {
			let file = try File(node: $0)
			fileDict[file.wspaceId]!.append(file)
		}
		return BulkUserInfo(user: user, projects: projects, workspaces: wspaceDict, files: fileDict)
	}
	
	/// get user with specified id
	///
	/// - Parameters:
	///   - id: the desired user's id
	///   - connection: optional database connection
	/// - Returns: user with specified id
	/// - Throws: .duplicate if more than one row in database matched, Node errors if problem parsing results
	public func getUser(id: Int, connection: Connection? = nil) throws -> User? {
		guard let node = try getSingleRow(connection, tableName: "rcuser", keyName: "id", keyValue: Node(integerLiteral: id)) else { return nil }
		return try User(node: node)
	}
	
	/// get user with specified login
	///
	/// - Parameters:
	///   - login: the desired user's login
	///   - connection: optional database connection
	/// - Returns: user with specified login
	/// - Throws: .duplicate if more than one row in database matched, Node errors if problem parsing results
	public func getUser(login: String, connection: Connection? = nil) throws -> User? {
		guard let node = try getSingleRow(connection, tableName: "rcuser", keyName: "login", keyValue: Node(stringLiteral: login)) else { return nil }
		return try User(node: node)
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
		guard let pgdb = self.pgdb else { fatalError("Rc2DAO accessed without connection") }
		let conn = connection == nil ? try pgdb.makeConnection() : connection!
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
	
	public func createSessionRecord(wspaceId: Int) throws -> Int {
		guard let pgdb = self.pgdb else { fatalError("Rc2DAO accessed without connection") }
		let conn = try pgdb.makeConnection()
		let query = "insert into sessionrecord (wspaceid) values ($1) returning id"
		let result = try conn.execute(query, [wspaceId])
		guard let array = result.array, array.count == 1 else {
			throw DBError.queryFailed
		}
		return try array[0].get("id")
	}
	
	public func closeSessionRecord(sessionId: Int) throws {
		guard let pgdb = self.pgdb else { fatalError("Rc2DAO accessed without connection") }
		let conn = try pgdb.makeConnection()
		let query = "update sessionrecord set closeDate = now() where id = $1"
		_ = try conn.execute(query, [sessionId])
	}
	
	/// get project with specific id
	///
	/// - Parameters:
	///   - id: id of the project
	///   - connection: optional database connection
	/// - Returns: project with id of id
	/// - Throws: .duplicate if more than one row in database matched, Node errors if problem parsing results
	public func getProject(id: Int, connection: Connection? = nil) throws -> Project? {
		guard let node = try getSingleRow(tableName: "rcproject", keyName: "id", keyValue: Node(integerLiteral: id))
			else { return nil }
		return try Project(node: node)
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
		guard let node = try getSingleRow(tableName: "rcworkspace", keyName: "id", keyValue: Node(integerLiteral: id))
			else { return nil }
		return try Workspace(node: node)
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
	///   - userId: the id of the user that owns the file
	///   - connection: optional database connection
	/// - Returns: file with id
	/// - Throws: .duplicate if more than one row in database matched, Node errors if problem parsing results
	public func getFile(id: Int, userId: Int, connection: Connection? = nil) throws -> File? {
		let values = [Node(integerLiteral: id), Node(integerLiteral: userId)]
		let query = "select f.* from rcfile f join rcworkspace w on f.wspaceId = w.id where w.userId = $2 and f.id = $1"
		guard let node = try getSingleRow(query: query, values: values)
			else { return nil }
		return try File(node: node)
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
		guard let data: Data = try result?.get("bindata") else { throw ModelError.notFound }
		return data
	}
	
	/// creates a new file
	///
	/// - Parameters:
	///   - name: name for the new file
	///   - wspaceId: id of the workspace the file belongs to
	///   - bytes: the contents of the file
	/// - Returns: the newly created file object
	/// - Throws: any database errors
	public func insertFile(name: String, wspaceId: Int, bytes: [UInt8]) throws -> File {
		guard let pgdb = self.pgdb else { fatalError("Rc2DAO accessed without connection") }
		return try queue.sync { () throws -> File in
			let conn = try pgdb.makeConnection()
			return try conn.transaction { () -> File in
				let insertRow = try conn.execute("insert into rcfile (wspaceid, name, filesize) values (\(wspaceId), $1, \(bytes.count)) returning *", [Node(stringLiteral: name)])
				guard let fileId: Int = try insertRow.get("id") else { throw DBError.queryFailed }
				try conn.execute("insert into rcfiledata (id, bindata) values ($1, $2)",
				                 [Bind(int: fileId, configuration: conn.configuration),
				                  Bind(bytes: bytes, configuration: conn.configuration)])
				return try File(node: insertRow)
			}
		}
	}
	
	/// Updates the contents of a file
	///
	/// - Parameters:
	///   - bytes: the updated content of the file
	///   - fileId: the id of the file
	/// - Throws: any database error
	public func setFile(bytes: [UInt8], fileId: Int) throws {
		guard let pgdb = self.pgdb else { fatalError("Rc2DAO accessed without connection") }
		try queue.sync { () throws -> Void in
			let conn = try pgdb.makeConnection()
			try conn.transaction { () -> Void in
				try conn.execute("update rcfile set version = version + 1, lastmodified = now(), filesize = \(bytes.count) where id = \(fileId)")
				try conn.execute("update rcfiledata set bindata = $1", [Bind(bytes: bytes, configuration: conn.configuration)])
			}
		}
	}
	
	/// Returns array of session images based on array of ids
	///
	/// - Parameter imageIds: Array of image ids
	/// - Returns: array of images
	/// - Throws: Node errors if problem fetching from database
	public func getImages(imageIds: [Int]?) throws -> [SessionImage] {
		guard let imageIds = imageIds, imageIds.count > 0 else { return [] }
		let idstring = imageIds.flatMap { String($0) }.joined(separator: ",")
		let query = "select * from sessionimage where id in (\(idstring)) order by id"
		let results = try getRows(query: query)
		return try results.map { try SessionImage(node: $0) }
	}
	
	//MARK: - private methods
	private func getSingleRow(_ connection: Connection? = nil, tableName: String, keyName: String, keyValue: Node) throws -> Node?
	{
		guard let pgdb = self.pgdb else { fatalError("Rc2DAO accessed without connection") }
		var finalResults: Node? = nil
		try queue.sync { () throws -> Void in
			let conn = connection == nil ? try pgdb.makeConnection() : connection!
			let result = try conn.execute("select * from \(tableName) where \(keyName) = $1", [keyValue])
			guard let array = result.array else { return }
			switch array.count {
				case 0:
					return
				case 1:
					finalResults = array[0]
				default:
					throw ModelError.duplicateObject
			}
		}
		return finalResults
	}

	private func getSingleRow(_ connection: Connection? = nil, query: String, values: [Node]) throws -> Node?
	{
		guard let pgdb = self.pgdb else { fatalError("Rc2DAO accessed without connection") }
		var finalResults: Node? = nil
		try queue.sync { () throws -> Void in
			let conn = connection == nil ? try pgdb.makeConnection() : connection!
			let result = try conn.execute(query, values)
			guard let array = result.array else { return }
			switch array.count {
			case 0:
				return
			case 1:
				finalResults = array[0]
			default:
				throw ModelError.duplicateObject
			}
		}
		return finalResults
	}

	private func getRows(_ connection: Connection? = nil, tableName: String, keyName: String, keyValue: Node) throws -> [Node]
	{
		guard let pgdb = self.pgdb else { fatalError("Rc2DAO accessed without connection") }
		var finalResults: [Node] = []
		try queue.sync  { () throws -> Void in
			let conn = connection == nil ? try pgdb.makeConnection() : connection!
			let result = try conn.execute("select * from \(tableName) where \(keyName) = $1", [keyValue])
			guard let array = result.array, array.count > 0 else {
				return
			}
			finalResults = array
		}
		return finalResults
	}
	
	private func getRows(query: String, connection: Connection? = nil) throws -> [Node] {
		guard let pgdb = self.pgdb else { fatalError("Rc2DAO accessed without connection") }
		var finalResults: [Node] = []
		try queue.sync  { () throws -> Void in
			let conn = connection == nil ? try pgdb.makeConnection() : connection!
			let result = try conn.execute(query)
			guard let array = result.array, array.count > 0 else {
				return
			}
			finalResults = array
		}
		return finalResults
	}
}
