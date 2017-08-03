import XCTest
@testable import Rc2AppServer
import Freddy
import Rc2Model
import PerfectNet
@testable import PerfectWebSockets
@testable import servermodel
import PostgreSQL

class SessionTests: XCTestCase {
	var session: Session!
	var dao: MockDAO!
	var wspace: Workspace!
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
		fakeNet = open("/dev/random", O_RDONLY)
		let tcp = NetTCP(fd: fakeNet)
		let ws = WebSocket(socket: tcp)
		dao = MockDAO()
		emptyProject = Project(id: 101, version: 1, userId: 101, name: "proj1")
		dao.emptyProject = emptyProject
		wspace = Workspace(id: 101, version: 1, name: "awspace", userId: 101, projectId: 101, uniqueId: "w2space1", lastAccess: Date(), dateCreated: Date())
		dao.wspace = wspace
		settings = AppSettings(dataDirURL: URL(fileURLWithPath: "/tmp/"), configData: "{}".data(using: .utf8), dao: dao)
		socketDelegate = MockSessionSocketDelegate()
		
		user = User(id: 101, version: 1, login: "test", email: "test@rc2.io")
		sessionSocket = MockSessionSocket(socket: ws, user: user, settings: settings, delegate: socketDelegate)
		session = Session(workspace: wspace, settings: settings)
		session.add(socket: sessionSocket)
		//that should have sent a user info message
		sessionSocket.messages.removeAll()
	}
	
	override func tearDown() {
		close(fakeNet)
	}

	// MARK: - response tests
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
	
	class MockDAO: Rc2DAO {
		var emptyProject: Project!
		var wspace: Workspace!
		override public func getProjects(ownedBy: User, connection: PostgreSQL.Connection? = nil) throws -> [Project] {
			return [emptyProject]
		}
		
		override func getUserInfo(user: User) throws -> BulkUserInfo {
			return BulkUserInfo(user: user, projects: [emptyProject], workspaces: [101: [wspace]], files: [:])
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


