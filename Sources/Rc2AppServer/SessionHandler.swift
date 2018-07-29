//
//  SessionHandler.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import Dispatch
import PerfectWebSockets
import PerfectHTTP
import MJLLogger
import Rc2Model
import BrightFutures

public class SessionHandler: WebSocketSessionHandler {
	private let settings: AppSettings
	private var activeSessions: [Int: Session] = [:]
	public var socketProtocol: String? = "rsession"
	private let lockQueue = DispatchQueue(label: "session handler")
	private var k8sServer: K8sServer?
	
	init(settings: AppSettings) {
		self.settings = settings
		if settings.config.computeViaK8s {
			do {
				self.k8sServer = try K8sServer(config: settings.config)
			} catch {
				Log.error("failed to create K8sServer: \(error)")
				fatalError("failed to create K8sServer")
			}
		}
		// TODO: need to schedule a timer that cleans up any sessions with no clients
	}
	
	// validates input from a request for a session
	private func validateSessionRequest(request req: HTTPRequest, socket: WebSocket) -> (Workspace, User)? {
		guard let loginToken = req.login else {
			Log.error("ws attempt without login")
			reportError(socket: socket, error: SessionError.permissionDenied)
			return nil
		}
		//figure out the user and the workspace they want to use
		guard let rawWspaceId = req.urlVariables["wsId"],
			let wspaceId = Int(rawWspaceId),
			let rawWspace = try? settings.dao.getWorkspace(id: wspaceId),
			let wspace = rawWspace
		else {
			reportError(socket: socket, error: SessionError.invalidRequest)
			return nil
		}
		guard
			wspace.userId == loginToken.userId,
			let rawUser = try? settings.dao.getUser(id: wspace.userId),
			let user = rawUser
		else {
			Log.warn("user doesn't have permission for requested workspace")
			reportError(socket: socket, error: SessionError.permissionDenied)
			return nil
		}
		return (wspace, user)
	}

	public func handleSession(request req: HTTPRequest, socket: WebSocket)
	{
		guard let (wspace, user) = validateSessionRequest(request: req, socket: socket) else {
			return //already reported error
		}
		let wspaceId = wspace.id
		// now have a workspace & user. find session
		let computePort = settings.config.computePort
		lockQueue.sync {
			var session = activeSessions[wspaceId]
			defer {
				//add connection to session
				let sessionSocket = SessionSocket(socket: socket, user: user, settings: settings, delegate: session!)
				session!.add(socket: sessionSocket)
				sessionSocket.start()
			}
			guard nil == session else { return }
			// need to create session and start compute engine
			session = Session(workspace: wspace, settings: settings)
			activeSessions[wspaceId] = session
			do {
				try session!.startSession(k8sServer: k8sServer)
			} catch {
				Log.info("error starting new session: \(error)")
				self.reportError(socket: socket, error: SessionError.failedToConnectToCompute)
				return
			}
		}
	}
	
	/// sends an error message on the socket and then closes it
	fileprivate func reportError(socket: WebSocket, error: SessionError)
	{
		guard let data = try? settings.encode(error) else {
			Log.error("failed to encode error")
			socket.close()
			return
		}
		Log.error("unknown error from server: \(String(data: data, encoding: .utf8)!)")
		socket.close()
	}
}

