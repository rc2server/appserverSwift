import XCTest
@testable import Rc2AppServer
import Freddy
import Rc2Model
import PerfectNet
@testable import PerfectWebSockets
@testable import servermodel
import PostgreSQL

// This unit of "response handling" has 3 interconnected types: ComputeCoder, SessionResponse, and Session (only the response handling part). Theoretically these all should be separate units, with a single integration test. Which is what this file really is. ComputeCoder and SessionResponse are basic enum/structs with no action methods to test (only serialization, which has to be tested here).

class SessionTests: XCTestCase {
	var session: Session!
	var dao: MockDAO!
	var emptyProject: Project!
	var settings: AppSettings!
	var user: User!
	var fakeNet: Int32 = -1
	var sessionSocket: MockSessionSocket!
	var socketDelegate: MockSessionSocketDelegate!
	
	static var allTests = [
		("testHelp", testHelp),
		]

	override func setUp() {
		continueAfterFailure = false
		fakeNet = open("/dev/random", O_RDONLY)
		let tcp = NetTCP(fd: fakeNet)
		let ws = WebSocket(socket: tcp)
		dao = MockDAO()
		emptyProject = Project(id: 101, version: 1, userId: 101, name: "proj1")
		dao.emptyProject = emptyProject
		settings = AppSettings(dataDirURL: URL(fileURLWithPath: "/tmp/"), configData: "{}".data(using: .utf8), dao: dao)
		socketDelegate = MockSessionSocketDelegate()
		
		user = User(id: 101, version: 1, login: "test", email: "test@rc2.io")
		sessionSocket = MockSessionSocket(socket: ws, user: user, settings: settings, delegate: socketDelegate)
		session = Session(workspace: dao.wspace101, settings: settings)
		session.add(socket: sessionSocket)
		//that should have sent a user info message
		sessionSocket.messages.removeAll()
	}
	
	override func tearDown() {
		continueAfterFailure = true
		close(fakeNet)
	}

	// MARK: - response tests
	
	func testOpenFailure() {
//		let json = """
//		{"msg":"openresponse", "success": false, "errorDetails": "" }
//		"""
		// TODO: implement
	}
	
	func testResponseWithImagesAndShowOutput() {
		let transId = "ddsad"
		_ = try! session.coder.executeScript(transactionId: transId, script: "what goes here doesn't matter, just need to get query id")
		let queryId = session.coder.queryId(for: transId)!
		let resultJson = """
		{"msg": "results", "stderr": false, "string": "[1] 44", "queryId": \(queryId)}
		"""
		session.handleCompute(data: resultJson.data(using: .utf8)!)
		let computeJson = """
		{"msg": "execComplete", "queryId": \(queryId), "expectShowOutput": true, "clientData": { "fileId": 11 }, "images": [ 23, 43 ], "imgBatch": 2 }
		"""
		session.handleCompute(data: computeJson.data(using: .utf8)!)
		let outputJson = """
		{"msg": "showoutput", "fileId": \(dao.file101.id), "fileVersion": 144, "fileName": "foo.pdf", "queryId": \(queryId)}
		"""
		session.handleCompute(data: outputJson.data(using: .utf8)!)
		
		XCTAssertEqual(sessionSocket.messages.count, 3)
		do {
			let response: SessionResponse = try settings.decode(data: sessionSocket.messages[0])
			XCTAssertNotNil(response)
			guard case let SessionResponse.results(results) = response else { XCTFail("invalid response"); return }
			XCTAssertEqual(results.isStdErr, false)
			XCTAssertEqual(results.transactionId, transId)

			let completeResponse: SessionResponse = try settings.decode(data: sessionSocket.messages[1])
			XCTAssertNotNil(completeResponse)
			guard case let SessionResponse.execComplete(execData) = completeResponse else { XCTFail("invalid execComplete response"); return }
//			XCTAssertEqual(execData.fileId, 11)
			XCTAssertEqual(execData.batchId, 2)
			XCTAssertEqual(execData.expectShowOutput, true)
			XCTAssertEqual(execData.transactionId, transId)
			XCTAssertEqual(execData.images.count, 2)
			XCTAssertEqual(execData.images[0], dao.image201)
			XCTAssertEqual(execData.images[1], dao.image202)
			
			let outputResponse: SessionResponse = try settings.decode(data: sessionSocket.messages[2])
			XCTAssertNotNil(outputResponse)
			guard case let SessionResponse.showOutput(outputData) = outputResponse else { XCTFail("invalid show output response"); return }
			XCTAssertEqual(outputData.transactionId, transId)
			XCTAssertEqual(outputData.file.id, dao.file101.id)
		} catch {
			fatalError("error decoding error object")
		}
	}
	
	func testVariableUpdate() {
//		let json = """
//		{"msg": "variableupdate", "delta": true, "variables": { "x1": { "name": "x1", "type": "f", "value": 1.23 } }
//		"""
		// TODO: implement
	}
	
	func testGetVariable() {
//		let json = """
//		{ "msg": "variablevalue", "name": "x2", { "name": "x2", "type": "f", "value": 1.23 } }
//		"""
		// TODO: implement
	}
	
	func testHelp() {
		let json = """
	{"msg":"help","paths":["/usr/lib/R/library/utils/help/zip", "/usr/lib/R/library/base/help/print"],"topic":"zip"}
"""
		session.handleCompute(data: json.data(using: .utf8)!)
		XCTAssertEqual(sessionSocket.messages.count, 1)
		let resultJson = String(data: sessionSocket.messages[0], encoding: .utf8)
		do {
			let response: SessionResponse.HelpData = try settings.decode(data: resultJson!.data(using: .utf8)!)
			XCTAssertNotNil(response)
			XCTAssertEqual(response.topic, "zip")
			XCTAssertEqual(response.items.count, 2)
			XCTAssertEqual(response.items["print (base)"], "/base/html/print.html")
		} catch {
			fatalError("error decoding help object")
		}
	}
	
	func testComputeError() {
		let json = """
		{ "msg":"error", "errorCode": \(SessionErrorCode.unknownFile.rawValue), "errorDetails": "foo.txt missing" }
		"""
		session.handleCompute(data: json.data(using: .utf8)!)
		XCTAssertEqual(sessionSocket.messages.count, 1)
		let resultJson = String(data: sessionSocket.messages[0], encoding: .utf8)
		do {
			let response: SessionResponse = try settings.decode(data: resultJson!.data(using: .utf8)!)
			XCTAssertNotNil(response)
			guard case let SessionResponse.error(errorData) = response else { XCTFail("invalid response"); return }
			guard case let SessionError.compute(code: code, details: details, transactionId: _) = errorData.error
				else { XCTFail("invalid error"); return }
			XCTAssertEqual(code, SessionErrorCode.unknownFile)
			XCTAssertEqual(details, "foo.txt missing")
		} catch {
			fatalError("error decoding error object")
		}
	}
	
	class MockDAO: Rc2DAO {
		var emptyProject: Project!
		var wspace101 = Workspace(id: 101, version: 1, name: "awspace", userId: 101, projectId: 101, uniqueId: "w2space1", lastAccess: Date(), dateCreated: Date())
		var file101 = File(id: 101, wspaceId: 101, name: "foo.pdf", version: 1, dateCreated: Date(), lastModified: Date(), fileSize: 1899)
		var image201 = SessionImage(id: 201, sessionId: 200, batchId: 2, name: "plot1.png", title: nil, dateCreated: Date(), imageData: Data(repeatElement(0x45, count: 890)))
		var image202 = SessionImage(id: 202, sessionId: 200, batchId: 2, name: "plot2.png", title: nil, dateCreated: Date(), imageData: Data(repeatElement(0x45, count: 211)))

		override public func getProjects(ownedBy: User, connection: PostgreSQL.Connection? = nil) throws -> [Project] {
			return [emptyProject]
		}
		
		override func getUserInfo(user: User) throws -> BulkUserInfo {
			return BulkUserInfo(user: user, projects: [emptyProject], workspaces: [101: [wspace101]], files: [101: [file101]])
		}
		
		override func getFile(id: Int, connection: Connection?) throws -> File? {
			guard id == file101.id else { return nil }
			return file101
		}
		
		override func getFileData(fileId: Int, connection: Connection?) throws -> Data {
			guard fileId == file101.id else { throw ModelError.notFound }
			return Data(repeatElement(0x45, count: file101.fileSize))
		}
		
		override func getImages(imageIds: [Int]?) throws -> [SessionImage] {
			return [ image201, image202 ]
		}
	}
	
	class MockSessionSocket: SessionSocket {
		var messages = [Data]()
		override func send(data: Data, completion: (@escaping () -> Void)) {
			messages.append(data)
			completion()
		}
	}
	
	class MockSessionSocketDelegate: SessionSocketDelegate {
		var callback: ((SessionCommand) -> Void)?
		
		func closed(socket: SessionSocket) {}
		func handle(command: SessionCommand, socket: SessionSocket) {
			callback?(command)
		}
	}

}


