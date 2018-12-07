//
//  SessionSocket.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import Dispatch
import PerfectWebSockets
import MJLLogger
import servermodel
import Rc2Model

protocol SessionSocketDelegate {
	func closed(socket: SessionSocket)
	func handle(command: SessionCommand, socket: SessionSocket)
}

class SessionSocket: Hashable {
	fileprivate let socket: WebSocket
	fileprivate let lockQueue: DispatchQueue
	let user: User
	let settings: AppSettings
	let delegate: SessionSocketDelegate
	weak var session: Session?
	var watchingVariables: Bool = false
	
	required init(socket: WebSocket, user: User, settings: AppSettings, delegate: SessionSocketDelegate) {
		self.socket = socket
		self.user = user
		self.settings = settings
		self.delegate = delegate
		lockQueue = DispatchQueue(label: "socket queue (\(user.login))")
	}
	
	var hashValue: Int { return ObjectIdentifier(self).hashValue }
	
	/// starts listening for messages
	func start() {
		DispatchQueue.global().async { [weak self] in
			self?.readNextMessage()
		}
	}
	
	func close() {
		lockQueue.sync {
			socket.close()
		}
	}

	func send(data: Data, completion: (@escaping () -> Void)) {
		lockQueue.sync {
			// TODO: this is copying the bytes. Is this possible to do w/o a copy? Maybe not, since it happens asynchronously
			let rawdata = [UInt8](data)
			socket.sendBinaryMessage(bytes: rawdata, final: true, completion: completion)
		}
	}
	
	/// start processing input
	private func readNextMessage() {
		socket.readBytesMessage { [weak self] (bytes, opcode, isFinal) in
			switch opcode {
			case .binary, .text:
				self?.handle(bytes: bytes)
			case .close, .invalid:
				self?.closed()
				return
			default:
				Log.error("got unhandled opcode \(opcode) from websocket")
			}
			DispatchQueue.global().async { [weak self] in
				self?.readNextMessage()
			}
		}
	}
	
	/// process bytes received from the network. only internal access control to allow for unit tests
	func handle(bytes: [UInt8]?) {
		guard let bytes = bytes else { return }
		//process bytes
		let data = Data(bytes)
		do {
			let command: SessionCommand = try settings.decode(data: data)
			delegate.handle(command: command, socket: self)
		} catch {
			Log.warn("Got error decoding message from client")
		}
	}
	
	/// called when remote closes the connection
	private func closed() {
		Log.info("remote closed socket connection")
		delegate.closed(socket: self)
	}
	
	// Equatable support
	static func == (lhs: SessionSocket, rhs: SessionSocket) -> Bool {
		return lhs.socket == rhs.socket
	}
}
