//
//  Session.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import PerfectLib
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
	private var sessionId: Int!
	private var isOpen: Bool = false
	
	// MARK: - initialization/startup
	
	init(workspace: Workspace, settings: AppSettings) {
		self.workspace = workspace
		self.settings = settings
		self.lockQueue = DispatchQueue(label: "workspace \(workspace.id)")
		coder = ComputeCoder()
	}
	
	public func startSession() throws {
		do {
			sessionId = try settings.dao.createSessionRecord(wspaceId: workspace.id)
		} catch {
			Log.logger.error(message: "failed to create session record \(error)", true)
			throw error
		}
		let net = NetTCP()
		do {
			try net.connect(address: settings.config.computeHost, port: settings.config.computePort, timeoutSeconds: settings.config.computeTimeout)
			{ socket in
				guard let socket = socket else { fatalError() }
				Log.logger.info(message: "connected to compute server", true)
				self.worker = ComputeWorker(workspace: self.workspace, sessionId: self.sessionId, socket: socket, settings: self.settings, delegate: self)
				self.worker?.start()
			}
		} catch {
			Log.logger.error(message: "failed to connect to compute engine", true)
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
			Log.logger.warning(message: "error sending to all client (\(error))", true)
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
			Log.logger.error(message: "failed to send BulkUserInfo \(error)", true)
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
		Log.logger.info(message: "got command: \(command)", true)
		switch command {
		case .help(let topic):
			handleHelp(topic: topic, socket: socket)
		case .execute(let params):
			handleExecute(params: params)
		case .executeFile(let params):
			handleExecuteFile(params: params)
		case .fileOperation(let params):
			handleFileOperation(params: params)
		case .getVariable(let name):
			handleGetVariable(name: name, socket: socket)
		case .watchVariables(let enable):
			handleWatchVariables(enable: enable, socket: socket)
		case .save(let params):
			handleSave(params: params, socket: socket)
		}
	}
}

// MARK: - Command Handling
extension Session {
	private func handleExecute(params: SessionCommand.ExecuteParams) {
		if params.isUserInitiated {
			broadcastToAllClients(object: SessionResponse.echoExecute(SessionResponse.ExecuteData(transactionId: params.transactionId, source: params.source)))
		}
		do {
			let data = try coder.executeScript(transactionId: params.transactionId, script: params.source)
			try lockQueue.sync {
				try worker?.send(data: data)
			}
		} catch {
			Log.logger.info(message: "error handling execute", true)
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
			Log.logger.info(message: "error handling execute", true)
		}
	}

	private func handleFileOperation(params: SessionCommand.FileOperationParams) {
		
	}
	
	private func handleGetVariable(name: String, socket: SessionSocket) {
		
	}
	
	private func handleWatchVariables(enable: Bool, socket: SessionSocket) {
		
	}
	
	private func handleSave(params: SessionCommand.SaveParams, socket: SessionSocket) {
		
	}
	
	private func handleHelp(topic: String, socket: SessionSocket) {
		do {
			let data = try? coder.help(topic: topic)
			try data?.write(to: URL(fileURLWithPath: "/tmp/url-out.txt"))
			try worker?.send(data: data!)
		} catch {
			Log.logger.warning(message: "error sending help message: \(error)", true)
		}
	}
}

// MARK: - compute delegate
extension Session: ComputeWorkerDelegate {
	/// handles a message from the compute engine
	/// - Parameter data: The binary message from the server
	func handleCompute(data: Data) {
		if let str = String(data: data, encoding: .utf8) {
			Log.logger.info(message: "got \(data.count) bytes: \(str)", true)
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
				handleVariableValueResponse(value: data)
			case .variables(let data):
				handleVariableListResponse(data: data)
			}
		} catch {
			Log.logger.error(message: "failed to parse response from data \(error)", true)
		}
	}
	
	/// Handle an error while processing data from the compute engine
	/// - Parameter error: the local error code
	func handleCompute(error: ComputeError) {
		Log.logger.error(message: "got error from compute engine \(error)", true)
	}
}

// MARK: - response handling
extension Session {
	func handleOpenResponse(success: Bool, errorMessage: String?) {
		isOpen = success
		if !success, let err = errorMessage {
			Log.logger.error(message: "Error opening compute connection: \(err)", true)
			broadcastToAllClients(object: SessionError.failedToConnectToCompute)
		}
	}
	
	func handleExecComplete(data: ComputeCoder.ExecCompleteData) {
		var images = [SessionImage]()
		do {
			images = try settings.dao.getImages(imageIds: data.imageIds)
		} catch {
			Log.logger.warning(message: "Error fetching images from compute \(error)", true)
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
				Log.logger.warning(message: "failed to find file \(data.fileId) to show output", true)
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
			Log.logger.warning(message: "error handling show file: \(error)", true)
		}
	}
	
	// path values of the format "/usr/lib/R/library/stats/help/Normal"
	func handleHelpResponse(topic: String, paths: [String]) {
		var outPaths = [String: String]()
		paths.forEach { value in
			if let rng = value.range(of: "/library/") {
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
				let title = funName + " (" + pkgName + ")"
				//add to outPaths with the display title as key, massaged path as value
				outPaths[title] = aPath
			}
		}
		let helpData = SessionResponse.HelpData(topic: topic, items: outPaths)
		broadcastToAllClients(object: SessionResponse.help(helpData))
	}
	
	func handleVariableValueResponse(value: Variable) {
		broadcastToAllClients(object: SessionResponse.variableValue(value))
	}
	
	func handleVariableListResponse(data: ComputeCoder.ListVariablesData) {
		let varData = SessionResponse.ListVariablesData(values: data.variables, delta: data.delta)
		broadcastToAllClients(object: SessionResponse.variables(varData))
	}
	
	func handleFileChanged(data: SessionResponse.FileChangedData) {
		broadcastToAllClients(object: SessionResponse.fileChanged(data))
	}
	
	func handleErrorResponse(data: ComputeCoder.ComputeErrorData) {
		let serror = SessionError.compute(code: data.code, details: data.details, transactionId: data.transactionId)
		let errorData = SessionResponse.ErrorData(transactionId: data.transactionId, error: serror)
		broadcastToAllClients(object: SessionResponse.error(errorData))
	}
}

