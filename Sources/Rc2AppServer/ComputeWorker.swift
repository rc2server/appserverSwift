//
//  ComputeWorker.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import Foundation
import Dispatch
import PerfectNet
import PerfectLib
import MJLLogger
import Rc2Model
import BrightFutures

fileprivate let ConnectTimeout = 5
fileprivate let maxFailureRetries = 3

public enum ComputeError: Error {
	case invalidHeader
	/// failed to connect to the monolithic server, assume can't retry connection
	case failedToConnect
	case failedToReadMessage
	case failedToWrite
	case invalidFormat
	case notConnected
	case tooManyCrashes
	case unknown
}

public protocol ComputeWorkerDelegate: class {
	func handleCompute(data: Data)
	func handleCompute(error: ComputeError)
	/// status updates just inform about a state change. If something failed, an error will be reported after the state change
	func handleCompute(statusUpdate: ComputeState)
}

/// used for a state machine of the connection status
public enum ComputeState: Int, CaseIterable {
	case uninitialized
	case initialHostSearch
	case loading
	case connecting
	case connected
	case failedToConnect
	case unusable
}

/// handles raw socket connection to the compute server, including making the connection
public class ComputeWorker {
	var socket: NetTCP?
	let readBuffer = Bytes()
	let config: AppConfiguration
	let wspaceId: Int
	let sessionId: Int
	let k8sServer: K8sServer?

	private(set) weak var delegate: ComputeWorkerDelegate?
	private let encoder = AppSettings.createJSONEncoder()
	private let decoder = AppSettings.createJSONDecoder()
	private(set) var state : ComputeState = .uninitialized { didSet {
		delegate?.handleCompute(statusUpdate: state)
	}}
//	private let compute = ComputeCoder()
	private var podFailureCount: Int = 0
	
	init(wspaceId: Int, sessionId: Int, k8sServer: K8sServer?, config: AppConfiguration, delegate: ComputeWorkerDelegate) {
		self.wspaceId = wspaceId
		self.sessionId = sessionId
		self.k8sServer = k8sServer
		self.config = config
		self.delegate = delegate
	}

	public func start() {
		assert(state == .uninitialized, "programmer error: invalid state")
		guard config.computeViaK8s else {
			openConnection(ipAddr: config.computeHost)
			return
		}
		guard k8sServer != nil else { fatalError("programmer error: can't use k8s without a k8s server") }
		// need to start dance of finding and/or launching the compute k8s pod
		state = .initialHostSearch
		updateStatus()
	}
	
	public func shutdown() throws {
		guard state == .connected else {
			Log.info("asked to shutdown when not running")
			throw ComputeError.notConnected
		}
		socket?.close()
	}
	
	public func send(data: Data) throws {
		guard state == .connected, let socket = socket else { throw ComputeError.notConnected }
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

	private func updateStatus() {
		guard let k8sServer = k8sServer else { fatalError("missing k8s server") }
		k8sServer.computeStatus(sessionId: sessionId).onSuccess { podStatus in
			guard let status = podStatus else {
				// not running. launch
				self.launchCompute()
				return
			}
			switch status.phase {
			case .pending:
				self.waitForPendingPod()
			case .running:
				self.openConnection(ipAddr: status.ipAddr)
			case .succeeded:
				// previous job is still there. Which means this sessionId has already been used and something is fucked up
				Log.error("pod for \(self.sessionId) is already successful")
				self.state = .failedToConnect
				self.delegate?.handleCompute(error: .failedToConnect)
			case .failed:
				// if too many failures, inform delegate
				self.podFailureCount += 1
				guard self.podFailureCount < maxFailureRetries else {
					Log.warn("too many pod failures")
					self.state = .unusable
					self.delegate?.handleCompute(error: .tooManyCrashes)
					return
				}
				// launch it again
				self.launchCompute()
			case .unknown:
				Log.warn("don't know how to handle unknown pod status")
				self.state = .failedToConnect
				self.delegate?.handleCompute(error: .failedToConnect)
			}
		}.onFailure { error in 
			self.state = .failedToConnect
			self.delegate?.handleCompute(error: .failedToConnect)
		}
	}

	private func waitForPendingPod() {
		self.state = .loading
		// TODO: this value should really scale with the number of attempts. First should be  second, then after 5 should go to 2 seconds, the after 20 should go to 5 seconds, etc.
		DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(2)) {
			self.updateStatus()
		}
	}

	private func launchCompute() {
		guard let k8sServer = k8sServer else { fatalError("missing k8s server") }
		state = .loading
		k8sServer.launchCompute(wspaceId: wspaceId, sessionId: sessionId).onSuccess { _ in 
			self.updateStatus()
		}.onFailure { error in 
			Log.error("error launching compute: \(error)")
			self.state = .unusable
			self.delegate?.handleCompute(error: .failedToConnect)
		}
	}

	private func openConnection(ipAddr: String) {
		let net = NetTCP()
		do {
			try net.connect(address: ipAddr, port: config.computePort, timeoutSeconds: config.computeTimeout)
			{ newSocket in
				guard let newSocket = newSocket else { 
					Log.error("failed to open IP connection")
					self.state = .failedToConnect
					self.delegate?.handleCompute(error: ComputeError.failedToConnect)
					return
				}
				self.socket = newSocket
				self.delegate?.handleCompute(statusUpdate: .connected)
				self.readNext()
			}
		} catch {
			Log.error("failed to connect to compute engine")
			delegate?.handleCompute(error: ComputeError.failedToConnect)
		}
	}
	
	// private func connectionOpened() {
	// 	do {
	// 		try send(data: compute.openConnection(wspaceId: workspace.id, sessionId: sessionId, dbhost: config.computeDbHost, dbuser: config.dbUser, dbname: config.dbName, dbpassword: config.dbPassword))
	// 		state = .connected
	// 		// only inform delegate when compute has replied to open message
	// 	} catch {
	// 		Log.error("Error opening compute connection: \(error)")
	// 		delegate?.handleCompute(error: ComputeError.failedToConnect)
	// 	}
	// 	readNext()
	// }

	private func readNext() {
		guard let socket = socket else { fatalError() }
		socket.readBytesFully(count: 8, timeoutSeconds: -1) { bytes in
			guard let bytes = bytes else { Log.error("readBytes got nil"); return }
			var readError: ComputeError?
			do {
				let size = try self.verifyMagicHeader(bytes: bytes)
				socket.readBytesFully(count: size, timeoutSeconds: -1) { (fullBytes) in
					guard let fullBytes = fullBytes else { readError = .failedToReadMessage; return }
					let data = Data(bytes: fullBytes)
					self.delegate?.handleCompute(data: data)
				}
			} catch {
				Log.error("got invalid header from client")
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
		Log.debug("compute sent \(dataLen) worth of json")
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
