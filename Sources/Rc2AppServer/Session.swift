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
	private var sessionId: Int!
	
	// MARK: - initialization/startup
	
	init(workspace: Workspace, settings: AppSettings) {
		self.workspace = workspace
		self.settings = settings
		self.lockQueue = DispatchQueue(label: "workspace \(workspace.id)")
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
			sockets.forEach { $0.send(data: data) { () in } }
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
			broadcastToAllClients(object: try settings.dao.getUserInfo(user: socket.user))
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
			handleWatchVaraibles(enable: enable, socket: socket)
		case .save(let params):
			handleSave(params: params, socket: socket)
		}
	}
}

// MARK: compute delegate
extension Session: ComputeWorkerDelegate {
	func handleCompute(data: Data) {
		if let str = String(data: data, encoding: .utf8) {
			Log.logger.info(message: "got \(data.count) bytes: \(str)", true)
		}
	}
	
	func handleCompute(error: ComputeError) {
		Log.logger.error(message: "got error from compute engine \(error)", true)
	}
}

// MARK: - Command Handling
extension Session {
	private func handleExecute(params: SessionCommand.ExecuteParams) {
		if params.isUserInitiated {
			broadcastToAllClients(object: SessionResponse.echoExecute(SessionResponse.ExecuteData(transactionId: params.transactionId, source: params.source)))
		}
	}
	
	private func handleExecuteFile(params: SessionCommand.ExecuteFileParams) {
		
	}

	private func handleFileOperation(params: SessionCommand.FileOperationParams) {
		
	}
	
	private func handleGetVariable(name: String, socket: SessionSocket) {
		
	}
	
	private func handleWatchVaraibles(enable: Bool, socket: SessionSocket) {
		
	}
	
	private func handleSave(params: SessionCommand.SaveParams, socket: SessionSocket) {
		
	}
	
	private func handleHelp(topic: String, socket: SessionSocket) {
		
	}
}
