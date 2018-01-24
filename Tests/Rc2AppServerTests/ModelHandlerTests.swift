//
//  ModelHandlerTests.swift
//
//  Copyright ©2017 Mark Lilback. This file is licensed under the ISC license.
//

import XCTest
@testable import Rc2AppServer
@testable import servermodel
import Rc2Model
import PerfectHTTP
import PostgreSQL

class ModelHandlerTests: XCTestCase {
	var settings: AppSettings!
	var dao: MockDAO!

	override func setUp() {
		continueAfterFailure = false
		dao = MHMockDAO()
		settings = AppSettings(dataDirURL: URL(fileURLWithPath: "/tmp/"), configData: "{}".data(using: .utf8), dao: dao)
	}

	func testDeleteWorkspaceTest() {
		let modelHandler = ModelHandler(settings: settings)
		XCTAssertNotNil(modelHandler)
		let request = MockHTTPRequest()
		let response = MockHTTPResponse(request: request, status: .ok)
		request.login = LoginToken(1, dao.user.id)
		request.urlVariables["projId"] = "1"
		request.urlVariables["wspaceId"] = "1"
		modelHandler.deleteWorkspace(request: request, response: response)
		XCTAssertEqual(response.status.description, HTTPResponseStatus.ok.description)
		XCTAssertEqual(response.header(.contentType), "application/json")
	}
	
	static var allTests = [
		("testDeleteWorkspaceTest", testDeleteWorkspaceTest),
	]
}

fileprivate class MHMockDAO: MockDAO {
	override func getProject(id: Int, connection: Connection?) throws -> Project?
	{
		return emptyProject
	}
	override func getWorkspace(id: Int, connection: Connection?) throws -> Workspace? {
		return wspace101
	}
	override func delete(workspaceId: Int) throws {
		print("deleted")
	}
}
