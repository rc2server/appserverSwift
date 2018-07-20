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
			Log.error("ws attempt without login")
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
			Log.warn("user doesn't have permission for requested workspace")
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
					// TODO: use k8s to open compute session if necessary
					try session?.startSession(host: settings.config.computeHost, port: settings.config.computePort)
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
			Log.error("failed to encode error")
			socket.close()
			return
		}
		Log.error("unknown error from server: \(String(data: data, encoding: .utf8)!)")
		socket.close()
	}
}

