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
				self.k8sServer = try K8sServer()
			} catch {
				Log.error("failed to create K8sServer: \(error)")
				fatalError("failed to create K8sServer")
			}
		}
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
		let computePort = settings.config.computePort
		lockQueue.sync {
			var session = activeSessions[wspaceId]
			if nil == session {
				session = Session(workspace: wspace, settings: settings)
				activeSessions[wspaceId] = session
				getComputeAddress(wspaceId: wspaceId).onSuccess { ipAddr in 
					do {
						try session?.startSession(host: ipAddr, port: computePort)
					} catch {
						Log.error("startSession failed: \(error)")
						self.reportError(socket: socket, error: SessionError.failedToConnectToCompute)
					}
				}.onFailure { error in 
					self.reportError(socket: socket, error: SessionError.failedToConnectToCompute)
				}
			}
			//add connection to session
			let sessionSocket = SessionSocket(socket: socket, user: user, settings: settings, delegate: session!)
			session!.add(socket: sessionSocket)
			sessionSocket.start()
		}
	}
	
	private func getComputeAddress(wspaceId: Int) -> Future<String, K8sError> {
		let promise = Promise<String, K8sError>()
		guard let server = k8sServer, settings.config.computeViaK8s else {
			Log.info("returning shared compute host")
			promise.success(settings.config.computeHost)
			return promise.future
		}
		Log.info("looking up ip address")
		server.hostName(wspaceId: wspaceId).onSuccess { ipAddr in 
			Log.info("got compute ip \(ipAddr ?? "nil")")
			promise.success(ipAddr ?? self.settings.config.computeHost)
		}.onFailure { error in 
			promise.failure(error)
		}
		return promise.future
	}

//	private func launchCompute(wspaceId: Int) -> Promise<String> {
//		return .value("invalid")
//	}

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

