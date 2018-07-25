//
//  Session.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import Dispatch
import MJLLogger
import Rc2Model
import servermodel
import PerfectNet

class Session {
	// MARK: - properties
	let workspace: Workspace
	let settings: AppSettings
	private let lockQueue: DispatchQueue
	private(set) var sockets = Set<SessionSocket>()
	/// allows whatever caches sessions to know when this session
	private(set) var lastClientDisconnectTime: Date?
	private var worker: ComputeWorker?
	let coder: ComputeCoder
	private var sessionId: Int?
	private var isOpen: Bool = false
	private var watchingVariables = false
	
	// MARK: - initialization/startup
	
	init(workspace: Workspace, settings: AppSettings) {
		self.workspace = workspace
		self.settings = settings
		self.lockQueue = DispatchQueue(label: "workspace \(workspace.id)")
		coder = ComputeCoder()
	}
	
	public func startSession(host: String, port: UInt16) throws {
		do {
			sessionId = try settings.dao.createSessionRecord(wspaceId: workspace.id)
			Log.info("got sessionId: \(sessionId ?? -1)")
		} catch {
			Log.error("failed to create session record \(error)")
			throw error
		}
		// the following should never fails, as we throw an error if fail to get a number
		guard let sessionId = sessionId else { fatalError() }
		let net = NetTCP()
		do {
			try net.connect(address: host, port: port, timeoutSeconds: settings.config.computeTimeout)
			{ socket in
				guard let socket = socket else { fatalError() }
				self.worker = ComputeWorker(workspace: self.workspace, sessionId: sessionId, socket: socket, settings: self.settings, delegate: self)
				self.worker?.start()
			}
		} catch {
			Log.error("failed to connect to compute engine")
			throw error
		}
		try settings.dao.addFileChangeObserver(wspaceId: workspace.id, callback: handleFileChanged)
	}
	
	public func shutdown() throws {
		try worker?.shutdown()
		sockets.removeAll()
	}
	
	// MARK: - Hashable/Equatable
	
	/// Hashable implementation
	var hashValue: Int { return ObjectIdentifier(self).hashValue }
	
	/// Equatable implementation
	static func == (lhs: Session, rhs: Session) -> Bool {
		return lhs.workspace.id == rhs.workspace.id
	}
}

// MARK: - client communications
extension Session {
	/// Send a message to all clients
	///
	/// - Parameter object: the message to send
	func broadcastToAllClients<T: Encodable>(object: T) {
		do {
			let data = try settings.encode(object)
			lockQueue.sync {
				sockets.forEach { $0.send(data: data) { () in } }
			}
		} catch {
			Log.warn("error sending to all client (\(error))")
		}
	}
	
	func broadcast<T: Encodable>(object: T, toClient clientId: Int) {
		do {
			let data = try settings.encode(object)
			if let socket = sockets.first(where: { $0.hashValue == clientId } ) {
				lockQueue.sync {
					socket.send(data: data, completion: { () in } )
				}
			}
		} catch {
			Log.warn("error sending to all client (\(error))")
		}
	}
}

// MARK: - Socket Management
extension Session {
	/// Add a socket/client to this session
	///
	/// - Parameter socket: the socket representing a new client
	func add(socket: SessionSocket) {
		lockQueue.sync {
			sockets.insert(socket)
			socket.session = self
			lastClientDisconnectTime = nil
		}
		do {
			let info = try settings.dao.getUserInfo(user: socket.user)
			broadcastToAllClients(object: SessionResponse.connected(info))
		} catch {
			Log.error("failed to send BulkUserInfo \(error)")
		}
	}
	
	/// Remove a socket/client from this session
	///
	/// - Parameter socket: the socket to remove from this session
	func remove(socket: SessionSocket) {
		lockQueue.sync {
			sockets.remove(socket)
			socket.session = nil
			if sockets.count == 0 {
				lastClientDisconnectTime = Date()
			}
		}
		// stop watching variables if currently watching and no sockets want to watch them
		if watchingVariables && !sockets.map({ $0.watchingVariables }).contains(true) {
			do {
				try worker?.send(data: try coder.toggleVariableWatch(enable: false, contextId: nil))
				watchingVariables = false
			} catch {
				Log.warn("error disabling variable watch: \(error)")
			}
		}
	}
}

// MARK: - SessionSocketDelegate
extension Session: SessionSocketDelegate {
	/// Called when a socket was remotely closed
	///
	/// - Parameter socket: the socket that closed
	func closed(socket: SessionSocket) {
		remove(socket: socket)
	}
	
	/// Handle a command from a client
	///
	/// - Parameters:
	///   - command: the command to handle
	///   - socket: the client that sent the command
	func handle(command: SessionCommand, socket: SessionSocket) {
		Log.info("got command: \(command)")
		switch command {
		case .clearEnvironment(let envId):
			handleClearEnvironment(id: envId)
		case .help(let topic):
			handleHelp(topic: topic, socket: socket)
		case .info:
			sendSessionInfo(socket: socket)
		case .execute(let params):
			handleExecute(params: params)
		case .executeFile(let params):
			handleExecuteFile(params: params)
		case .fileOperation(let params):
			handleFileOperation(params: params)
		case .getVariable(let params):
			handleGetVariable(params: params, socket: socket)
		case .watchVariables(let params):
			handleWatchVariables(params: params, socket: socket)
		case .save(let params):
			handleSave(params: params, socket: socket)
		}
	}
}

// MARK: - Command Handling
extension Session {
	private func handleExecute(params: SessionCommand.ExecuteParams) {
		if params.isUserInitiated {
			broadcastToAllClients(object: SessionResponse.echoExecute(SessionResponse.ExecuteData(transactionId: params.transactionId, source: params.source, contextId: params.contextId)))
		}
		do {
			let data = try coder.executeScript(transactionId: params.transactionId, script: params.source)
			try lockQueue.sync {
				try worker?.send(data: data)
			}
		} catch {
			Log.info("error handling execute \(error.localizedDescription)")
		}
	}
	
	private func handleExecuteFile(params: SessionCommand.ExecuteFileParams) {
		broadcastToAllClients(object: SessionResponse.echoExecuteFile(SessionResponse.ExecuteFileData(transactionId: params.transactionId, fileId: params.fileId, fileVersion: params.fileVersion)))
		do {
			let data = try coder.executeFile(transactionId: params.transactionId, fileId: params.fileId, fileVersion: params.fileVersion)
			try lockQueue.sync {
				try worker?.send(data: data)
			}
		} catch {
			Log.info("error handling execute")
		}
	}

	private func handleFileOperation(params: SessionCommand.FileOperationParams) {
		var cmdError: SessionError?
		var fileId = params.fileId
		var dupfile: Rc2Model.File? = nil
		do {
			switch params.operation {
			case .remove:
				try settings.dao.delete(fileId: params.fileId)
			case .rename:
				guard let name = params.newName else { throw SessionError.invalidRequest }
				_ = try settings.dao.rename(fileId: params.fileId, version: params.fileVersion, newName: name)
			case .duplicate:
				guard let name = params.newName else { throw SessionError.invalidRequest }
				dupfile = try settings.dao.duplicate(fileId: fileId, withName: name)
				fileId = dupfile!.id
				break
			}
		} catch let serror as SessionError {
			Log.warn("file operation \(params.operation) on \(params.fileId) failed: \(serror)")
			cmdError = serror
		} catch {
			Log.warn("file operation \(params.operation) on \(params.fileId) failed: \(error)")
			cmdError = SessionError.databaseUpdateFailed
		}

		let data = SessionResponse.FileOperationData(transactionId: params.transactionId, operation: params.operation, success: cmdError == nil, fileId: fileId, file: dupfile, error: cmdError)
		broadcastToAllClients(object: SessionResponse.fileOperation(data))
		sendSessionInfo(socket: nil)
	}
	
	private func handleClearEnvironment(id: Int) {
		// TODO: implement
		//do {
		//	let cmd = try coder
		//} catch {
		//	Log.warn("error clearing environment \(error)")
		//}
	}
	
	private func handleGetVariable(params: SessionCommand.VariableParams, socket: SessionSocket) {
		do { 
			let cmd = try coder.getVariable(name: params.name, contextId: params.contextId, clientIdentifier: socket.hashValue)
			try worker?.send(data: cmd)
		} catch {
			Log.warn("error getting variable: \(error)")
		}
	}
	
	// toggle variable watch on the compute server if it needs to be based on this request
	private func handleWatchVariables(params: SessionCommand.WatchVariablesParams, socket: SessionSocket) {
		guard params.watch != socket.watchingVariables else { return } // nothing to change
		socket.watchingVariables = params.watch
		// should we still be watching?
		let shouldWatch = sockets.map({ $0.watchingVariables }).contains(true)
		// either toggle if overall change in state, otherwise ask for updated list so socket can know all the current values
		do {
			var cmd = try coder.toggleVariableWatch(enable: shouldWatch, contextId: params.contextId)
			if shouldWatch, shouldWatch == watchingVariables {
				// ask for updated values
				cmd = try coder.listVariables(deltaOnly: false, contextId: params.contextId)
			}
			try worker?.send(data: cmd)
			watchingVariables = shouldWatch
		} catch {
			Log.warn("error toggling variable watch: \(error)")
		}
	}
	
	/// save file changes and broadcast appropriate response
	private func handleSave(params: SessionCommand.SaveParams, socket: SessionSocket) {
		var serror: SessionError?
		var updatedFile: Rc2Model.File?
		do {
			updatedFile = try settings.dao.setFile(bytes: Array<UInt8>(params.content), fileId: params.fileId, fileVersion: params.fileVersion)
		} catch let dberr as Rc2DAO.DBError {
			serror = SessionError(dbError: dberr)
			if serror == .unknown {
				Log.warn("unknown error saving file: \(dberr)")
			}
		} catch {
			Log.warn("unknown error saving file: \(error)")
			serror = SessionError.unknown
		}
		let responseData = SessionResponse.SaveData(transactionId: params.transactionId, success: serror != nil, file: updatedFile, error: serror)
		broadcastToAllClients(object: SessionResponse.save(responseData))
	}
	
	/// send updated workspace info
	private func sendSessionInfo(socket: SessionSocket?) {
		do {
			let response = SessionResponse.InfoData(workspace: workspace, files: try settings.dao.getFiles(workspace: workspace))
			broadcastToAllClients(object: SessionResponse.info(response))
		} catch {
			Log.warn("error sending info: \(error)")
		}
	}
	
	private func handleHelp(topic: String, socket: SessionSocket) {
		do {
			let data = try? coder.help(topic: topic)
			try data?.write(to: URL(fileURLWithPath: "/tmp/url-out.txt"))
			try worker?.send(data: data!)
		} catch {
			Log.warn("error sending help message: \(error)")
		}
	}
}

// MARK: - compute delegate
extension Session: ComputeWorkerDelegate {
	/// handles a message from the compute engine
	/// - Parameter data: The binary message from the server
	func handleCompute(data: Data) {
		if let str = String(data: data, encoding: .utf8) {
			Log.info("got \(data.count) bytes: \(str)")
		}
		do {
			let response = try coder.parseResponse(data: data)
			switch response {
			case .open(success: let success, errorMessage: let errMsg):
				handleOpenResponse(success: success, errorMessage: errMsg)
			case .execComplete(let execData):
				handleExecComplete(data: execData)
			case .error(let errorData):
				handleErrorResponse(data: errorData)
			case .help(topic: let topic, paths: let paths):
				handleHelpResponse(topic: topic, paths: paths)
			case .results(let data):
				handleResultsResponse(data: data)
			case .showFile(let data):
				handleShowFileResponse(data: data)
			case .variableValue(let data):
				handleVariableValueResponse(data: data)
			case .variables(let data):
				handleVariableListResponse(data: data)
			}
		} catch {
			Log.error("failed to parse response from data \(error)")
		}
	}
	
	/// Handle an error while processing data from the compute engine
	/// - Parameter error: the local error code
	func handleCompute(error: ComputeError) {
		Log.error("got error from compute engine \(error)")
	}
}

// MARK: - response handling
extension Session {
	func handleOpenResponse(success: Bool, errorMessage: String?) {
		isOpen = success
		if !success, let err = errorMessage {
			Log.error("Error in response to open compute connection: \(err)")
			let errorObj = SessionResponse.error(SessionResponse.ErrorData(transactionId: nil, error: SessionError.failedToConnectToCompute))
			broadcastToAllClients(object: errorObj)
		}
	}
	
	func handleExecComplete(data: ComputeCoder.ExecCompleteData) {
		var images = [SessionImage]()
		do {
			images = try settings.dao.getImages(imageIds: data.imageIds)
		} catch {
			Log.warn("Error fetching images from compute \(error)")
		}
		let cdata = SessionResponse.ExecCompleteData(transactionId: data.transactionId, batchId: data.batchId ?? 0, expectShowOutput: data.expectShowOutput, images: images)
		broadcastToAllClients(object: SessionResponse.execComplete(cdata))
	}
	
	func handleResultsResponse(data: ComputeCoder.ResultsData) {
		let sresults = SessionResponse.ResultsData(transactionId: data.transactionId, output: data.text, isError: data.isStdErr)
		broadcastToAllClients(object: SessionResponse.results(sresults))
	}
	
	func handleShowFileResponse(data: ComputeCoder.ShowFileData) {
		do {
			//refetch from database so we have updated information
			//if file is too large, only send meta info
			guard let file = try settings.dao.getFile(id: data.fileId, userId: workspace.userId) else {
				Log.warn("failed to find file \(data.fileId) to show output")
				handleErrorResponse(data: ComputeCoder.ComputeErrorData(code: .unknownFile, details: "unknown file requested", transactionId: data.transactionId))
				return
			}
			var fileData: Data? = nil
			if file.fileSize < (settings.config.maximumWebSocketFileSizeKB * 1024) {
				fileData = try settings.dao.getFileData(fileId: data.fileId)
			}
			let forClient = SessionResponse.ShowOutputData(transactionid: data.transactionId, file: file, fileData: fileData)
			broadcastToAllClients(object: SessionResponse.showOutput(forClient))
		} catch {
			Log.warn("error handling show file: \(error)")
		}
	}
	
	// path values of the format "/usr/lib/R/library/stats/help/Normal"
	func handleHelpResponse(topic: String, paths: [String]) {
		var outPaths = [String: String]()
		paths.forEach { value in
			guard let rng = value.range(of: "/library/") else { return }
			//strip off everything before "/library"
			let idx = value.index(rng.upperBound, offsetBy: -1)
			var aPath = String(value[idx...])
			//replace "help" with "html"
			aPath = aPath.replacingOccurrences(of: "/help/", with: "/html/")
			aPath.append(".html") // add file extension
			// split components
			var components = value.split(separator: "/")
			let funName = components.last!
			let pkgName = components.count > 3 ? components[components.count - 3] : "Base"
			let title = String(funName + " (" + pkgName + ")")
			//add to outPaths with the display title as key, massaged path as value
			outPaths[title] = aPath
		}
		let helpData = SessionResponse.HelpData(topic: topic, items: outPaths)
		broadcastToAllClients(object: SessionResponse.help(helpData))
	}
	
	func handleVariableValueResponse(data: ComputeCoder.VariableData) {
		let value = SessionResponse.VariableValueData(value: data.variable, contextId: data.contextId)
		let responseObject = SessionResponse.variableValue(value)
		if let clientId = data.clientId {
			broadcast(object: responseObject, toClient: clientId)
		} else {
			broadcastToAllClients(object: responseObject)
		}
	}
	
	func handleVariableListResponse(data: ComputeCoder.ListVariablesData) {
		// we send to everyone, even those not watching
		Log.info("handling list variable data with \(data.variables.count) variables")
		let varData = SessionResponse.ListVariablesData(values: data.variables, removed: data.removed, contextId: data.contextId, delta: data.delta)
		Log.info("forwarding \(data.variables.count) variables")
		broadcastToAllClients(object: SessionResponse.variables(varData))
	}
	
	func handleFileChanged(data: SessionResponse.FileChangedData) {
		Log.info("got file change \(data)")
		broadcastToAllClients(object: SessionResponse.fileChanged(data))
	}
	
	func handleErrorResponse(data: ComputeCoder.ComputeErrorData) {
		let serror = SessionError.compute(code: data.code, details: data.details, transactionId: data.transactionId)
		let errorData = SessionResponse.ErrorData(transactionId: data.transactionId, error: serror)
		broadcastToAllClients(object: SessionResponse.error(errorData))
	}
}

extension SessionError {
	init(dbError: Rc2DAO.DBError) {
		switch dbError {
		case .queryFailed:
			self = .databaseUpdateFailed
		case .connectionFailed:
			self = .unknown
		case .invalidFile:
			self = .invalidRequest
		case .versionMismatch:
			self = .fileVersionMismatch
		case .noSuchRow:
			self = .invalidRequest
		}
	}
}
