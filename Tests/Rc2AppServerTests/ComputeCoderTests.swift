import XCTest
@testable import Rc2AppServer
import Freddy

class ComputeCoderTests: XCTestCase {
	var coder: ComputeCoder!
	
	static var allTests = [
		("testOpenSuccess", testOpenSuccess),
		("testOpenFailure", testOpenFailure),
		("testOpenMalformed", testOpenMalformed),
		("testHelpSuccess", testOpenSuccess),
		("testHelpMalformed", testOpenMalformed),
		("testErrorSuccess", testErrorSuccess),
		("testErrorMalformed", testErrorMalformed),
		("testBasicExecFile", testBasicExecFile),
		("testResults", testResults),
		("testHelp", testHelp),
		("testOpen", testOpen),
		("testClose", testClose),
		("testHelp", testHelp),
		("testGetVariable", testGetVariable),
		("testSaveEnvironment", testSaveEnvironment),
		("testExecuteFile", testExecuteFile),
		("testExecuteScript", testExecuteScript),
		("testToggleWatch", testToggleWatch),
		("testListVariables", testListVariables),
		]

	override func setUp() {
		coder = ComputeCoder()
	}
	
	// MARK: - request tests
	func testGetVariable() {
		let data = try! coder.getVariable(name: "foo123")
		let json = try! JSON(data: data)
		XCTAssertEqual(try! json.getString(at: "msg"), "getVariable")
		XCTAssertEqual(try! json.getString(at: "argument"), "foo123")
	}
	
	func testHelp() {
		let data = try! coder.help(topic: "rnorm")
		let json = try! JSON(data: data)
		XCTAssertEqual(try! json.getString(at: "msg"), "help")
		XCTAssertEqual(try! json.getString(at: "argument"), "rnorm")
	}
	
	func testSaveEnvironment() {
		let data = try! coder.saveEnvironment()
		let json = try! JSON(data: data)
		XCTAssertEqual(try! json.getString(at: "msg"), "saveEnv")
	}
	
	func testExecuteScript() {
		let tid = "foo1"
		let script = "rnorm(20)"
		let data = try! coder.executeScript(transactionId: tid, script: script)
		let json = try! JSON(data: data)
		XCTAssertEqual(try! json.getString(at: "msg"), "execScript")
		XCTAssertEqual(try! json.getString(at: "argument"), script)
	}
	
	func testExecuteFile() {
		let fileId = 23
		let tid = "foo2"
		let data = try! coder.executeFile(transactionId: tid, fileId: fileId)
		let json = try! JSON(data: data)
		XCTAssertEqual(try! json.getString(at: "msg"), "execFile")
		XCTAssertEqual(try! json.getInt(at: "clientData", "fileId"), fileId)
	}

	func testToggleWatch() {
		let data = try! coder.toggleVariableWatch(enable: true)
		let json = try! JSON(data: data)
		XCTAssertEqual(try! json.getString(at: "msg"), "toggleVariableWatch")
		XCTAssertEqual(try! json.getString(at: "argument"), "")
		XCTAssertEqual(try! json.getBool(at: "watch"), true)
	}
	
	func testClose() {
		let data = try! coder.close()
		let json = try! JSON(data: data)
		XCTAssertEqual(try! json.getString(at: "msg"), "close")
		XCTAssertEqual(try! json.getString(at: "argument"), "")
	}
	
	func testListVariables() {
		let data = try! coder.listVariables(deltaOnly: true)
		let json = try! JSON(data: data)
		XCTAssertEqual(try! json.getBool(at: "delta"), true)
		XCTAssertEqual(try! json.getString(at: "msg"), "listVariables")
		XCTAssertEqual(try! json.getString(at: "argument"), "")
	}
	
	func testOpen() {
		let wspaceId = 101
		let sessionId = 22012
		let dbHost = "dbserver"
		let dbUser = "rc2"
		let dbName = "rc2d"
		let data = try! coder.openConnection(wspaceId: wspaceId, sessionId: sessionId, dbhost: dbHost, dbuser: dbUser, dbname: dbName)
		let json = try! JSON(data: data)
		XCTAssertEqual(try! json.getString(at: "msg"), "open")
		XCTAssertEqual(try! json.getInt(at: "wspaceId"), wspaceId)
		XCTAssertEqual(try! json.getInt(at: "sessionRecId"), sessionId)
		XCTAssertEqual(try! json.getString(at: "dbhost"), dbHost)
		XCTAssertEqual(try! json.getString(at: "dbuser"), dbUser)
		XCTAssertEqual(try! json.getString(at: "dbname"), dbName)
	}
	
	// MARK: - Response tests
	func testOpenSuccess() {
		let openJson = """
	{"msg": "openresponse", "success": true }
"""
		let openRsp = try! coder.parseResponse(data: openJson.data(using: .utf8)!)
		guard case let ComputeCoder.Response.open(success: success, errorMessage: _) = openRsp else {
			XCTFail("invalid open response")
			return
		}
		XCTAssertEqual(success, true)
	}

	func testOpenFailure() {
		let json = """
	{"msg": "openresponse", "success": false, "errorDetails": "test error" }
"""
		let resp = try! coder.parseResponse(data: json.data(using: .utf8)!)
		guard case let ComputeCoder.Response.open(success: success, errorMessage: openErrorString) = resp else {
			XCTFail("invalid open response")
			return
		}
		XCTAssertEqual(success, false)
		XCTAssertEqual(openErrorString, "test error")
	}

	func testOpenMalformed() {
		let json = """
	{"msg": "openresponse", "success": false, "foobar": "test error" }
"""
		XCTAssertThrowsError(try coder.parseResponse(data: json.data(using: .utf8)!))
	}
	
	func testHelpSuccess() {
		let json = """
	{"msg": "help", "topic": "print", "paths": [ "/foo", "/bar" ] }
"""
		let resp = try! coder.parseResponse(data: json.data(using: .utf8)!)
		guard case let ComputeCoder.Response.help(topic: topic, paths: paths) = resp
		else { XCTFail("invalid help response"); return }
		XCTAssertEqual(topic, "print")
		XCTAssertEqual(paths.count, 2)
		XCTAssertEqual(paths[0], "/foo")
		XCTAssertEqual(paths[1], "/bar")
	}

	func testHelpMalformed() {
		let json = """
	{"msg": "help", "topic": "print" }
"""
		XCTAssertThrowsError(try coder.parseResponse(data: json.data(using: .utf8)!))
	}
	
	func testErrorSuccess() {
		let json = """
{"msg": "error", "errorCode": 123, "errorDetails": "foobar"}
"""
		let resp = try! coder.parseResponse(data: json.data(using: .utf8)!)
		guard case let ComputeCoder.Response.error(errrsp) = resp
			else { XCTFail("invalid error response"); return }
		XCTAssertEqual(errrsp.code, 123)
		XCTAssertEqual(errrsp.details, "foobar")
	}

	func testErrorMalformed() {
		let json = """
{"msg": "error", "Code": 123, "details": "foobar"}
"""
		XCTAssertThrowsError(try coder.parseResponse(data: json.data(using: .utf8)!))
	}
	
	func testBasicExecFile() {
		let qid = queryId(for: "foo1")
		let json = """
		{ "msg": "execComplete", "transactionId": "foo1", "queryId": \(qid), "expectShowOutput": true, "clientData": { "fileId": 33 }, "imgBatch": 22, "images": [ 111, 222 ] }
"""
		// expect
		let resp = try! coder.parseResponse(data: json.data(using: .utf8)!)
		guard case let ComputeCoder.Response.execComplete(execData) = resp
			else { XCTFail("failed to parse exec complete"); return }
		XCTAssertEqual(execData.transactionId, "foo1")
		XCTAssertEqual(execData.fileId, 33)
		XCTAssertEqual(execData.expectShowOutput, true)
		XCTAssertEqual(execData.batchId, 22)
		XCTAssertEqual(execData.imageIds?.count, 2)
		XCTAssertEqual(execData.imageIds?[0], 111)
		XCTAssertEqual(execData.imageIds?[1], 222)
	}
	
	func testResults() {
		let qid = queryId(for: "foo2")
		let json = """
		{ "msg": "results", "stderr": false, "string": "R output", "queryId": \(qid) }
		"""
		let resp = try! coder.parseResponse(data: json.data(using: .utf8)!)
		guard case let ComputeCoder.Response.results(results) = resp
			else { XCTFail("failed to get results"); return }
		XCTAssertEqual(results.isStdErr, false)
		XCTAssertEqual(results.transactionId, "foo2")
		XCTAssertEqual(results.text, "R output")
	}
	
	func testShowOutput() {
		let qid = queryId(for: "foo3")
		let json = """
		{ "msg": "showoutput", "fileId": 22, "fileVersion": 1, "fileName" : "foobar.pdf", "queryId": \(qid) }
"""
		let resp = try! coder.parseResponse(data: json.data(using: .utf8)!)
		guard case let ComputeCoder.Response.showFile(results) = resp
			else { XCTFail("failed to show output"); return }
		XCTAssertEqual(results.fileId, 22)
		XCTAssertEqual(results.transactionId, "foo3")
		XCTAssertEqual(results.fileVersion, 1)
		XCTAssertEqual(results.fileName, "foobar.pdf")
	}
	
	// TODO: add tests for variableValue and variables when those responses are properly handled
	
	// MARK: - helper methods
	private func queryId(for transId: String) -> Int {
		let reqData = try! coder.executeScript(transactionId: transId, script: "rnorm(20)")
		let reqJson = try! JSON(data: reqData)
		return try! reqJson.getInt(at: "queryId")
	}
}
