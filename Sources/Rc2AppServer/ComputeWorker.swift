//
//  ComputeWorker.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import PerfectNet
import PerfectLib
import Rc2Model

fileprivate let ConnectTimeout = 5

public enum ComputeError: Error {
	case invalidHeader
	case failedToReadMessage
	case failedToWrite
	case unknown
}

public protocol ComputeWorkerDelegate: class {
	func handleCompute(data: Data)
	func handleCompute(error: ComputeError)
}

public class ComputeWorker {
	let socket: NetTCP
	let readBuffer = Bytes()
	let settings: AppSettings
	let workspace: Workspace
	let sessionId: Int
	private(set) weak var delegate: ComputeWorkerDelegate?
	private let encoder = JSONEncoder()
	private let decoder = JSONDecoder()
	private let compute = ComputeCoder()
	
	public init(workspace: Workspace, sessionId: Int, socket: NetTCP, settings: AppSettings, delegate: ComputeWorkerDelegate) {
		self.workspace = workspace
		self.sessionId = sessionId
		self.socket = socket
		self.settings = settings
		self.delegate = delegate

		decoder.dataDecodingStrategy = .base64
		decoder.dateDecodingStrategy = .millisecondsSince1970
		decoder.nonConformingFloatDecodingStrategy = .convertFromString(positiveInfinity: "Inf", negativeInfinity: "-Inf", nan: "NaN")
}
	
	public func start() {
		do {
			try send(data: compute.openConnection(wspaceId: workspace.id, sessionId: sessionId, dbhost: settings.config.computeDbHost, dbuser: settings.config.dbUser, dbname: settings.config.dbName))
		} catch {
			Log.logger.error(message: "Error opening compute connection: \(error)", true)
			// TODO close Session and tell client
		}
		readNext()
	}
	
	public func shutdown() throws {
		try send(data: compute.close())
		try settings.dao.closeSessionRecord(sessionId: sessionId)
	}
	
	public func send(data: Data) throws {
		// write header
		var headBytes = [UInt8](repeating: 0, count: 8)
		headBytes.replaceSubrange(0...3, with: valueByteArray(UInt32(0x21).byteSwapped))
		headBytes.replaceSubrange(4...7, with: valueByteArray(UInt32(data.count).byteSwapped))
		guard socket.writeFully(bytes: headBytes) else { throw ComputeError.failedToWrite }
		// write data. FIXME: should be able to do this without a copy or casting to NSData
		var dataBytes = [UInt8](repeating: 0, count: data.count)
		dataBytes.withUnsafeMutableBufferPointer { ptr in
			data.copyBytes(to: ptr.baseAddress!, count: data.count)
		}
		socket.write(bytes: dataBytes) { _ in }
	}
	
	private func readNext() {
		socket.readBytesFully(count: 8, timeoutSeconds: -1) { bytes in
			guard let bytes = bytes else { Log.logger.error(message: "readBytes got nil", true); return }
			var readError: ComputeError?
			do {
				let size = try self.verifyMagicHeader(bytes: bytes)
				self.socket.readBytesFully(count: size, timeoutSeconds: -1) { (fullBytes) in
					guard let fullBytes = fullBytes else { readError = .failedToReadMessage; return }
					let data = Data(bytes: fullBytes)
					self.delegate?.handleCompute(data: data)
				}
			} catch {
				Log.logger.error(message: "got invalid header from client", true)
				//TODO: signal error to client
				if let err = error as? ComputeError {
					readError = err
				} else {
					readError = .unknown
				}
			}
			if let error = readError {
				self.delegate?.handleCompute(error: error)
			}
			DispatchQueue.global().async {
				self.readNext()
			}
		}
	}
	
	private func verifyMagicHeader(bytes: [UInt8]) throws -> Int {
		let (header, dataLen) = UnsafePointer<UInt8>(bytes).withMemoryRebound(to: UInt32.self, capacity: 2) { return (UInt32(bigEndian: $0.pointee), UInt32(bigEndian: $0.advanced(by: 1).pointee))}
		// tried all kinds of withUnsafePointer & withMemoryRebound and could not figure it out.
		Log.logger.info(message: "compute sent \(dataLen) worth of json", true)
		guard header == 0x21 else { throw ComputeError.invalidHeader }
		return Int(dataLen)
	}

	fileprivate func valueByteArray<T>(_ value:T) -> [UInt8] {
		var data = [UInt8](repeatElement(0, count: MemoryLayout<T>.size))
		data.withUnsafeMutableBufferPointer {
			UnsafeMutableRawPointer($0.baseAddress!).storeBytes(of: value, as: T.self)
		}
		return data
	}
}