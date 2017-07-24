//
//  Rc2SessionHandler.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import PerfectWebSockets
import PerfectHTTP
import PerfectLib
import Rc2Model

public class Rc2SessionHandler: WebSocketSessionHandler {
	private let settings: AppSettings
	public var socketProtocol: String? = "rsession"
	
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
		let session = Session(workspace: wspace)
		//add connection to session
		let sessionSocket = SessionSocket(socket: socket, user: user, settings: settings)
		session.add(socket: sessionSocket)
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
