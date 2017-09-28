//
//  FileChangeMonitor.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import Dispatch
import PostgreSQL
import PerfectLib
import Rc2Model

extension String {
	func after(integerIndex: Int) -> Substring {
		precondition(integerIndex < count && integerIndex > 0)
		let start = self.index(startIndex, offsetBy: integerIndex)
		return self[start...]
	}
	
	func to(integerIndex: Int) -> Substring {
		precondition(integerIndex < count && integerIndex >= 0)
		let end = self.index(startIndex, offsetBy: integerIndex)
		return self[startIndex...end]
	}
	
	func stringTo(integerIndex: Int) -> String {
		return String(self.to(integerIndex: integerIndex))
	}
}

class FileChangeMonitor {
	typealias Observer = (SessionResponse.FileChangedData) -> Void
	
	private var dbConnection: DBConnection
	private let queue: DispatchQueue
	private var observers = [(Int, Observer)]()
	// has to be var or can't pass a callback that is a method on this object in the initializer
	private var reader: DispatchSourceRead!
	
	init(connection: DBConnection, queue: DispatchQueue = .global()) throws {
		dbConnection = connection
		self.queue = queue
		reader = try connection.makeListenDispatchSource(toChannel: "rcfile", queue: queue, callback: handleNotification)
		reader.activate()
	}
	
	deinit {
		reader.cancel()
	}
	
	func add(wspaceId: Int, observer: @escaping Observer) {
		observers.append((wspaceId, observer))
	}
	
	// internal to allow unit testing
	internal func handleNotification(notification: DBNotification?, error: Error?) {
		guard let msg = notification?.payload else {
			Log.logger.warning(message: "FileChangeMonitor got error from database: \(error!)", true)
			return
		}
		let msgParts = msg.after(integerIndex: 1).split(separator: "/")
		guard msgParts.count == 3,
			let wspaceId = Int(msgParts[0]),
			let fileId = Int(msgParts[1])
		else {
			Log.logger.warning(message: "received unknown message \(msg) from db on rcfile channel", true)
			return
		}
		let msgType = String(msg[msg.startIndex...msg.startIndex]) // a lot of work to get first character as string
		Log.logger.info(message: "received rcfile notification for file \(fileId) in wspace \(wspaceId)", true)
		guard let changeType = SessionResponse.FileChangedData.FileChangeType(rawValue: msgType)
			else { Log.logger.warning(message: "invalid change notifiction from db \(msg)", true); return }
		var file: Rc2Model.File?
		if let results = try? dbConnection.execute(query: "select * from rcfile where id = \(fileId)", values: []),
			let array = results.array,
			array.count == 1
		{
			file = try? File(node: array[0])
		}
		let changeData = SessionResponse.FileChangedData(type: changeType, file: file, fileId: fileId)
		observers.forEach { if wspaceId == $0.0 { $0.1(changeData) } }
	}
}

extension String {
	func substring(to: Int) -> String {
		let idx = index(startIndex, offsetBy: to)
		return String(self[..<idx])
	}
}
