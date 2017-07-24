//
//  SessionHandler.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
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
	}
	
	public func handleSession(request req: HTTPRequest, socket: WebSocket)
	{
		guard let loginToken = req.login else {
			Log.logger.error(message: "ws attempt without login", false)
			fatalError(socket: socket, error: SessionError.permissionDenied)
			return
		}
		//figure out the user and the workspace they want to use
		guard req.path.hasPrefix("/ws/"),
			let idx = req.path.index(req.path.startIndex, offsetBy: 4, limitedBy: req.path.endIndex),
			let path = Optional.some(req.path.substring(from: idx)),
			let wspaceId = Int(path),
			let rawWspace = try? settings.dao.getWorkspace(id: wspaceId),
			let wspace = rawWspace,
			wspace.userId == loginToken.userId,
			let rawUser = try? settings.dao.getUser(id: wspace.userId),
			let user = rawUser
		else {
			fatalError(socket: socket, error: SessionError.invalidRequest)
			return
		}
		// now have a workspace & user. find session
		lockQueue.sync {
			var session = activeSessions[wspaceId]
			if nil == session {
				session = Session(workspace: wspace)
				activeSessions[wspaceId] = session
			}
			//add connection to session
			let sessionSocket = SessionSocket(socket: socket, user: user, settings: settings, delegate: self)
			session!.add(socket: sessionSocket)
			sessionSocket.start()
		}
	}
	
	/// sends an error message on the socket and then closes it
	fileprivate func fatalError(socket: WebSocket, error: SessionError)
	{
		guard let data = try? settings.encoder.encode(error) else {
			return
		}
		data.withUnsafeBytes { bytes in
			socket.sendBinaryMessage(bytes: bytes.pointee, final: true) {
				socket.close()
			}
		}
	}
}

extension SessionHandler: SessionSocketDelegate {
	func socketClosed(_ socket: SessionSocket) {
		guard let session = socket.session else { return }
		lockQueue.sync {
			session.remove(socket: socket)
			if session.sockets.count < 1 {
				// TODO: shutdown the session, remove from activeSessions
			}
		}
	}
}
