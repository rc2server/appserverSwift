//
//  ComputeCommand.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation

/// object to transform data send/received from the compute engine
class ComputeCoder {
	// MARK: - properties
	private let encoder = JSONEncoder()
	private var nextQueryId: Int = 1
	private var transactionIds = [String: Int]()
	private let queue = DispatchQueue(label: "ComputeCommand Queue")
	
	// MARK: - initialization
	/// creates an object that generates the for commands to send to the compute engine
	init() {
		encoder.dataEncodingStrategy = .base64
		encoder.dateEncodingStrategy = .millisecondsSince1970
		encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "Inf", negativeInfinity: "-Inf", nan: "NaN")
	}
	
	// MARK: - request methods
	/// Create the data to request a variable's value
	/// 
	/// - Parameter name: The name of the variable to get
	/// - Returns: data to send to compute server
	func getVariable(name: String) throws -> Data {
		let obj = GenericCommand(msg: "getVariable", argument: name)
		return try encoder.encode(obj)
	}

	/// Create the data to request help for a topic
	/// 
	/// - Parameter topic: The help topic to query
	/// - Returns: data to send to compute server
	func help(topic: String) throws -> Data {
		return try encoder.encode(GenericCommand(msg: "help", argument: topic))
	}

	/// Create the data to save the environment
	/// 
	/// - Returns: data to send to compute server
	func saveEnvironment() throws -> Data {
		return try encoder.encode(GenericCommand(msg: "saveEnv", argument: ""))
	}

	/// Create the data to execute a query
	/// 
	/// - Parameter transactionId: The unique transactionId
	/// - Parameter query: The query to execute
	/// - Returns: data to send to compute server
	func executeScript(transactionId: String, query: String) throws -> Data {
		return try encoder.encode(ExecuteQuery(queryId: createQueryId(transactionId), script: query))
	}
	
	/// Create the data to execute a file
	/// 
	/// - Parameter transactionId: The unique transactionId
	/// - Parameter fileId: The id of the file to execute
	/// - Returns: data to send to compute server
	func executeFile(transactionId: String, fileId: Int) throws -> Data {
		return try encoder.encode(ExecuteFile(fileId: fileId, queryId: createQueryId(transactionId)))
	}
	
	/// Create the data to toggle variable watching
	/// 
	/// - Parameter enable: Should variables be watched
	/// - Returns: data to send to compute server
	func toggleVariableWatch(enable: Bool) throws -> Data {
		return try encoder.encode(ToggleVariables(watch: enable))
	}
	
	/// Create the data to close the connection gracefully
	/// 
	/// - Returns: data to send to compute server
	func close() throws -> Data {
		return try encoder.encode(GenericCommand(msg: "close", argument: ""))
	}
	
	/// Create the data to request a list of variables and their values
	/// 
	/// - Parameter deltaOnly: Should it return only changed values, or all values
	/// - Returns: data to send to compute server
	func listVariables(deltaOnly: Bool) throws -> Data {
		return try encoder.encode(ListVariableCommand(delta: deltaOnly))
	}
	
	/// Create the data to open a connection to the compute server
	/// 
	/// - Parameter wspaceId: id of the workspace to use
	/// - Parameter sessionid: id of the session record to use for this session
	/// - Parameter dbhost: The hostname for the database server
	/// - Parameter dbuser: The username to log into the database with
	/// - Parameter dbname: The name of the database to connect to
	/// - Returns: data to send to compute server
	func openConnection(wspaceId: Int, sessionId: Int, dbhost: String, dbuser: String, dbname: String) throws -> Data {
		return try encoder.encode(OpenCommand(wspaceId: wspaceId, sessionRecId: sessionId, dbhost: dbhost, dbuser: dbuser, dbname: dbname))
	}
	
	// MARK: - internal methods
	private func createQueryId(_ transactionId: String) -> Int {
		var qid: Int = 0
		queue.sync {
			qid = nextQueryId
			self.nextQueryId = nextQueryId + 1
			transactionIds[transactionId] = qid
		}
		return qid
	}
	
	// MARK: - private structs for command serialization
	private struct OpenCommand: Encodable {
		let msg = "open"
		let argument = ""
		let wspaceId: Int
		let sessionRecId: Int
		let dbhost: String
		let dbuser: String
		let dbname: String
	}
	
	private struct GenericCommand: Encodable {
		let msg: String
		let argument: String
	}
	
	private struct ListVariableCommand: Encodable {
		let msg = "listVariables"
		let argument = ""
		let delta: Bool
		
		init(delta: Bool) {
			self.delta = delta
		}
	}

	private struct ToggleVariables: Encodable {
		let msg = "toggleVariableWatch"
		let argument = ""
		let watch: Bool
		
		init(watch: Bool) {
			self.watch = watch
		}
	}

	private struct ExecuteFile: Encodable {
		let msg = "execFile"
		let startTime = Date()
		let argument: String
		let queryId: Int
		let clientData: [String: Int]
		
		init(fileId: Int, queryId: Int) {
			argument = "\(fileId)"
			self.queryId = queryId
			var cdata = [String: Int]()
			cdata["fileId"] = fileId
			clientData = cdata
		}
	}
	
	private struct ExecuteQuery: Encodable {
		let msg = "execScript"
		let queryId: Int
		let argument: String
		let startTime = Date()
		
		init(queryId: Int, script: String) {
			self.queryId = queryId
			self.argument = script
		}
	}
}
