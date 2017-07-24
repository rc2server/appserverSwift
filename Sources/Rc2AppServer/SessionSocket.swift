//
//  SessionSocket.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import PerfectWebSockets
import PerfectLib
import servermodel
import Rc2Model

protocol SessionSocketDelegate {
	func closed(socket: SessionSocket)
	func handle(command: SessionCommand, socket: SessionSocket)
}

class SessionSocket: Hashable {
	let socket: WebSocket
	let user: User
	let settings: AppSettings
	let delegate: SessionSocketDelegate
	weak var session: Session?
	
	init(socket: WebSocket, user: User, settings: AppSettings, delegate: SessionSocketDelegate) {
		self.socket = socket
		self.user = user
		self.settings = settings
		self.delegate = delegate
	}
	
	var hashValue: Int { return ObjectIdentifier(self).hashValue }
	
	func start() {
		socket.readBytesMessage { [weak self] (bytes, opcode, isFinal) in
			switch opcode {
			case .binary, .text:
				self?.handle(bytes: bytes)
			case .close, .invalid:
				self?.closed()
			default:
				Log.logger.error(message: "got unhandled opcode \(opcode) from websocket", true)
			}
		}
	}
	
	private func handle(bytes: [UInt8]?) {
		guard let bytes = bytes else { return }
		//process bytes
		let data = Data(bytes)
		do {
			let command = try settings.decoder.decode(SessionCommand.self, from: data)
			delegate.handle(command: command, socket: self)
		} catch {
			Log.logger.warning(message: "Got error decoding message from client", true)
		}
	}
	
	private func closed() {
		delegate.closed(socket: self)
	}
	
	static func == (lhs: SessionSocket, rhs: SessionSocket) -> Bool {
		return lhs.socket == rhs.socket
	}
}
