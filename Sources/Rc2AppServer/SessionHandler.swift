//
//  SessionHandler.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import Dispatch
import PerfectWebSockets
import PerfectHTTP
import PerfectLib
import Rc2Model

public class SessionHandler: WebSocketSessionHandler {
	private let settings: AppSettings
	private var activeSessions: [Int: Session] = [:]
	public var socketProtocol: String? = "rsession"
	private let lockQueue = DispatchQueue(label: "session handler")
	
	init(settings: AppSettings) {
		self.settings = settings
		// TODO: need to schedule a timer that cleans up any sessions with no clients
	}
	
	public func handleSession(request req: HTTPRequest, socket: WebSocket)
	{
		guard let loginToken = req.login else {
			Log.logger.error(message: "ws attempt without login", false)
			reportError(socket: socket, error: SessionError.permissionDenied)
			return
		}
		//figure out the user and the workspace they want to use
		guard let rawWspaceId = req.urlVariables["wsId"],
			let wspaceId = Int(rawWspaceId),
			let rawWspace = try? settings.dao.getWorkspace(id: wspaceId),
			let wspace = rawWspace
		else {
			reportError(socket: socket, error: SessionError.invalidRequest)
			return
		}
		guard
			wspace.userId == loginToken.userId,
			let rawUser = try? settings.dao.getUser(id: wspace.userId),
			let user = rawUser
		else {
			Log.logger.warning(message: "user doesn't have permission for requested workspace", true)
			reportError(socket: socket, error: SessionError.permissionDenied)
			return
		}
		// now have a workspace & user. find session
		lockQueue.sync {
			var session = activeSessions[wspaceId]
			if nil == session {
				session = Session(workspace: wspace, settings: settings)
				activeSessions[wspaceId] = session
				do {
					try session?.startSession()
				} catch {
					fatalError("failed to start session \(error)")
				}
			}
			//add connection to session
			let sessionSocket = SessionSocket(socket: socket, user: user, settings: settings, delegate: session!)
			session!.add(socket: sessionSocket)
			sessionSocket.start()
		}
	}
	
	/// sends an error message on the socket and then closes it
	fileprivate func reportError(socket: WebSocket, error: SessionError)
	{
		guard let data = try? settings.encode(error) else {
			Log.logger.error(message: "failed to encode error", true)
			socket.close()
			return
		}
		data.withUnsafeBytes { bytes in
			socket.sendBinaryMessage(bytes: bytes.pointee, final: true) {
				socket.close()
			}
		}
	}
}

