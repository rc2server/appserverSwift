import XCTest
@testable import servermodel
import Rc2Model
#if os(Linux)
	import Glibc
	import Dispatch
#else
import Darwin
#endif

class FileChangeMonitorTests: XCTestCase {
	fileprivate var connection: ChangeMockDB!
	var monitor: FileChangeMonitor!
	var lastChange: SessionResponse.FileChangedData?
	
	override func setUp() {
		connection = ChangeMockDB()
		monitor = try! FileChangeMonitor(connection: connection)
	}
	
	func testValidNotfications() {
		let note = MockDBNotification(pid: 1, channel: "rcfile", payload: "u/101/102/3")
		monitor.add(wspaceId: 102, observer: changeHandler)
		monitor.handleNotification(notification: note, error: nil)
		XCTAssertNotNil(lastChange)
		XCTAssertEqual(lastChange?.fileId, 101)
		XCTAssertEqual(lastChange?.changeType, SessionResponse.FileChangedData.FileChangeType.update)
	}

	func changeHandler(_ data: SessionResponse.FileChangedData) {
		lastChange = data
	}

	static var allTests = [
		("testValidNotfications", testValidNotfications),
	]
}

fileprivate class ChangeMockDB: MockDBConnection {
	// returns a source on /dev/random.
	override func makeListenDispatchSource(toChannel channel: String, queue: DispatchQueue, callback: @escaping (DBNotification?, Error?) -> Void) throws -> DispatchSourceRead
	{
		#if os(OSX)
			let fd = Darwin.open("/dev/random", O_RDONLY)
		#else
			let fd = Glibc.open("/dev/random", O_RDONLY)
		#endif
		guard fd >= 2 else { fatalError() }
		let src = DispatchSource.makeReadSource(fileDescriptor: fd, queue: DispatchQueue.global())
		src.setCancelHandler {
			#if os(Linux)
				Glibc.close(fd)
			#else
				Darwin.close(fd)
			#endif
		}
		return src
	}
}
