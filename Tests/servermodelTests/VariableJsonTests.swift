//
//  VariableJsonTests.swift
//  Rc2AppServerTests
//
//  Created by Mark Lilback on 11/13/17.
//

import XCTest
@testable import Rc2Model
@testable import servermodel
import Freddy

class VariableJsonTests: XCTestCase {
	static var allTests = [
		("testFactor", testFactor),
	]

	override func setUp() {
		super.setUp()
	}
	
	override func tearDown() {
		super.tearDown()
	}

	func testDataFrame() throws {
		let json = """
		{"class":"data.frame","columns":[{"name":"c1","type":"b","values":[false,true,null,null,true,false]}, {"name":"c2","type":"d","values":[3.14,null,"NaN",21.0,"Inf","-Inf"]},{"name":"c3","type":"s","values":["Aladdin",null,"NA","Mario","Mark","Alex"]},{"name":"c4","type":"i","values":[1,2,3,null,5,null]}],"name":"cdf","ncol":4,"nrow":6,"row.names":["1","2","3","4","5","6"],"summary":"JSONSerialization barfs on a real R summary text with control characters"}
		"""
		let parsedJson = try JSON(jsonString: json)
		let variable = try! Variable.makeFromLegacy(json: parsedJson)
		guard let dfData = variable.dataFrameData else { XCTFail("failed to extract dataframedata"); return }
		XCTAssertEqual(dfData.columns.count, 4)
		XCTAssertEqual(dfData.columns[0].name, "c1")
		XCTAssertEqual(dfData.columns[1].name, "c2")
		XCTAssertEqual(dfData.columns[2].name, "c3")
		XCTAssertEqual(dfData.columns[3].name, "c4")
		guard case let .boolean(c1vals) = dfData.columns[0].value else { XCTFail("failed to get bool data from c1"); return }
		XCTAssertTrue(compare(c1vals, [false, true, nil, nil, true, false]))
		// can't test double values as nan != nan
		guard case let .string(c3vals) = dfData.columns[2].value else { XCTFail("failed to get double data from c3"); return }
		XCTAssertTrue(compare(c3vals, ["Aladdin",nil,"NA","Mario","Mark","Alex"]))
	}
	

	func testFactor() throws {
		let json = """
		{"value": [1, 1, 3, 4, 2, 5], "summary": " Factor w/ 5 levels \\"a\\",\\"b\\",\\"c\\",\\"d\\",..: 1 1 3 4 2 5", "levels": ["a", "b", "c", "d", "e"], "type": "f", "name": "f", "class": "factor"}
		"""
		let parsedJson = try JSON(jsonString: json)
		let variable = try! Variable.makeFromLegacy(json: parsedJson)
		XCTAssertEqual(variable.name, "f")
		XCTAssertTrue(variable.isFactor)
		guard case .factor(let vals, let levels) =  variable.type else { XCTFail("failed to parse factor"); return }
		XCTAssertEqual(vals.count, 6)
		XCTAssertEqual(levels?.count, 5)
		XCTAssertEqual(vals, [1, 1, 3, 4, 2, 5])
		XCTAssertEqual(levels!, ["a", "b", "c", "d", "e"])
	}

}
