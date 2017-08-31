import XCTest
@testable import Rc2AppServer
@testable import servermodel
import Rc2Model
import PerfectHTTP

class appserverlibTests: XCTestCase {
	var settings: AppSettings!
	var dao: MockDAO!
	
	override func setUp() {
		continueAfterFailure = false
		dao = MockDAO()
		settings = AppSettings(dataDirURL: URL(fileURLWithPath: "/tmp/"), configData: "{}".data(using: .utf8), dao: dao)
	}
	
    func testInfoRestRequest() {
		let infoHandler = InfoHandler(settings: settings)
		XCTAssertNotNil(infoHandler)
		let request = MockHTTPRequest()
		let response = MockHTTPResponse(request: request, status: .ok)
		request.login = LoginToken(1, dao.user.id)
		infoHandler.getBulkInfo(request: request, response: response)
		XCTAssertEqual(response.header(.contentType), "application/json")
		XCTAssertEqual(response.status.description, HTTPResponseStatus.ok.description)
		do {
			let data = Data(bytes: response.bodyBytes)
			let info: BulkUserInfo = try settings.decode(data: data)
			XCTAssertNotNil(info)
			// the following will work once Xcode is updated to automatically generate Euatable implementations
//			XCTAssertEqual(info.user, dao.user)
		} catch {
			XCTFail("failed: \(error)")
		}
    }

    static var allTests = [
        ("testInfoRestRequest", testInfoRestRequest),
    ]
}
