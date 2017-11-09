//
//  ComputeCommand.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import Dispatch
import LoggerAPI
import Rc2Model
import servermodel

/// object to transform data send/received from the compute engine
class ComputeCoder {
	private let clientDataKey = "clientData"
	// MARK: - properties
	private let encoder = JSONEncoder()
	private let decoder = JSONDecoder()
	private var nextQueryId: Int = 1
	private var transactionIds = [String: Int]()
	private var queryIds = [Int: String]()
	private let queue = DispatchQueue(label: "ComputeCommand Queue")
	
	// MARK: - initialization
	/// creates an object that generates the for commands to send to the compute engine
	init() {
		encoder.dateEncodingStrategy = .millisecondsSince1970
		encoder.nonConformingFloatEncodingStrategy = .convertToString(positiveInfinity: "Inf", negativeInfinity: "-Inf", nan: "NaN")
		decoder.dateDecodingStrategy = .millisecondsSince1970
		decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "Inf", negativeInfinity: "-Inf", nan: "NaN")
	}
	
	// MARK: - request methods
	/// Create the data to request a variable's value
	/// 
	/// - Parameter name: The name of the variable to get
	/// - Returns: data to send to compute server
	func getVariable(name: String, clientIdentifier: Int? = nil) throws -> Data {
		let obj = GetVariableCommand(name: name, clientIdentifier: clientIdentifier)
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
	func executeScript(transactionId: String, script: String) throws -> Data {
		return try encoder.encode(ExecuteQuery(queryId: createQueryId(transactionId), script: script))
	}
	
	/// Create the data to execute a file
	/// 
	/// - Parameter transactionId: The unique transactionId
	/// - Parameter fileId: The id of the file to execute
	/// - Returns: data to send to compute server
	func executeFile(transactionId: String, fileId: Int, fileVersion: Int) throws -> Data {
		return try encoder.encode(ExecuteFile(fileId: fileId, fileVersion: fileVersion, queryId: createQueryId(transactionId)))
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
	
	// MARK: - response handling
	
	func parseResponse(data: Data) throws -> Response {
		guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
			let msg = json["msg"] as? String
		else {
			throw ComputeError.invalidFormat
		}
		let queryId = json["queryId"] as? Int
		let transId = queryIds[queryId ?? 0]
		switch msg {
		case "openresponse":
			guard let success = json["success"] as? Bool else { throw ComputeError.invalidFormat }
			let errorDetails = json["errorMessage"] as? String
			if !success && errorDetails == nil { throw ComputeError.invalidFormat }
			return Response.open(success: success, errorMessage: errorDetails)
		case "execComplete":
			guard let expect = json["expectShowOutput"] as? Bool, let transId = transId else { throw ComputeError.invalidFormat }
			var fileId: Int?
			if let clientData = json[clientDataKey] as? [String: Int], let parsedFileId = clientData["fileId"] {
				fileId = parsedFileId
			}
			return Response.execComplete(ExecCompleteData(fileId: fileId, imageIds: json["images"] as? [Int], batchId: json["imgBatch"] as? Int, transactionId: transId, expectShowOutput: expect))
		case "results":
			// FIXME: does this send stderr or stdout or both? really shouldn't be a guard
			guard let isNotErr = json["stdout"] as? Bool, let transId = transId, let text = json["string"] as? String
			else { throw ComputeError.invalidFormat }
			return Response.results(ResultsData(text: text, isStdErr: !isNotErr, transactionId: transId))
		case "showoutput":
			guard let fileId = json["fileId"] as? Int,
				let fileVersion = json["fileVersion"] as? Int,
				let fileName = json["fileName"] as? String,
				let transId = transId
			else { throw ComputeError.invalidFormat }
			return Response.showFile(ShowFileData(fileId: fileId, fileVersion: fileVersion, fileName: fileName, transactionId: transId))
		case "variableupdate":
			guard let delta = json["delta"] as? Bool else { throw ComputeError.invalidFormat }
			let variableData: ListVariablesData
			if delta {
				guard let data = json["variables"] as? [String: Any],
					let assignedData = data["assigned"] as? [String: [String: Any]],
					let removed = data["removed"] as? [String]
				else { throw ComputeError.invalidFormat }
				let assigned = assignedData.flatMap({ try? Variable.makeFromLegacy(dict: $0.1) })
				variableData = ListVariablesData(variables: assigned, removed: removed, delta: true)
			} else {
				var vars: [Variable]?
				if !(json["variables"] is NSNull) {
					guard let data = json["variables"] as? [String: [String: Any]] else { throw ComputeError.invalidFormat }
					vars = data.flatMap({ try? Variable.makeFromLegacy(dict: $0.1) })
				}
				variableData = ListVariablesData(variables: vars, removed: [], delta: delta)
			}
			return Response.variables(variableData)
		case "variablevalue":
			guard let value = try? Variable.makeFromLegacy(dict: json) else { throw ComputeError.invalidFormat }
			var ident: Int? = nil
			if let clientData = json[clientDataKey] as? [String: Int],
				let cident = clientData[GetVariableCommand.clientIdentKey]
			{
				ident = cident
			}
			return Response.variableValue(VariableData(variable: value, clientId: ident))
		case "help":
			guard let topic = json["topic"] as? String, let paths = json["paths"] as? [String] else { throw ComputeError.invalidFormat }
			return Response.help(topic: topic, paths: paths)
		case "error":
			guard let code = json["errorCode"] as? Int else { throw ComputeError.invalidFormat }
			let ecode = SessionErrorCode(rawValue: code) ?? SessionErrorCode.unknown
			let edata = ComputeErrorData(code: ecode, details: json["errorDetails"] as? String, transactionId: transId)
			return Response.error(edata)
		default:
			Log.error("unknown response from compute engine: \(msg)")
			throw ComputeError.invalidFormat
		}
	}
	
	/// enum representing a parsed response
	enum Response {
		case open(success: Bool, errorMessage: String?)
		case execComplete(ExecCompleteData)
		case error(ComputeErrorData)
		case help(topic: String, paths: [String])
		case results(ResultsData)
		case showFile(ShowFileData)
		case variableValue(VariableData)
		case variables(ListVariablesData)
	}
	
	struct ComputeErrorData {
		let code: SessionErrorCode
		let details: String?
		let transactionId: String?
	}

	struct ExecCompleteData {
		let fileId: Int?
		let imageIds: [Int]?
		let batchId: Int?
		let transactionId: String
		let expectShowOutput: Bool
	}
	
	struct ResultsData {
		let text: String
		let isStdErr: Bool
		let transactionId: String
	}
	
	struct ShowFileData {
		let fileId: Int
		let fileVersion: Int
		let fileName: String
		let transactionId: String
	}
	
	struct ListVariablesData {
		let variables: [Variable]?
		let removed: [String]
		let delta: Bool
	}
	
	struct VariableData {
		let variable: Variable
		let clientId: Int?
	}
	
	// MARK: - internal methods
	private func createQueryId(_ transactionId: String) -> Int {
		var qid: Int = 0
		queue.sync {
			qid = nextQueryId
			self.nextQueryId = nextQueryId + 1
			transactionIds[transactionId] = qid
			queryIds[qid] = transactionId
		}
		return qid
	}
	
	// For internal usage to lookup a transactionId
	func queryId(for transId: String) -> Int? {
		return transactionIds[transId]
	}

	// MARK: - private structs for command serialization
	struct OpenCommand: Codable {
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
	
	private struct GetVariableCommand: Encodable {
		static let clientIdentKey = "clientIdent"
		let msg = "getVariable"
		let argument: String
		let clientData: [String: Int]?
		
		init(name: String, clientIdentifier: Int? = nil) {
			argument = name
			if let cident = clientIdentifier {
				clientData = [GetVariableCommand.clientIdentKey: cident]
			} else {
				clientData = nil
			}
		}
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
		let startTime = Int(Date().timeIntervalSince1970).description
		let argument: String
		let queryId: Int
		let clientData: [String: Int]
		
		init(fileId: Int, fileVersion: Int, queryId: Int) {
			argument = "\(fileId)"
			self.queryId = queryId
			var cdata = [String: Int]()
			cdata["fileId"] = fileId
			cdata["fileVersion"] = fileVersion
			clientData = cdata
		}
	}
	
	struct ExecuteQuery: Codable {
		let msg = "execScript"
		let queryId: Int
		let argument: String
		let startTime = Int(Date().timeIntervalSince1970).description
		
		init(queryId: Int, script: String) {
			self.queryId = queryId
			self.argument = script
		}
	}
}
