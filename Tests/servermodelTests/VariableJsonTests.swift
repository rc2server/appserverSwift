//
//  VariableJsonTests.swift
//  Rc2AppServerTests
//
//  Created by Mark Lilback on 11/13/17.
//

import XCTest
import Rc2Model
@testable import servermodel
import Freddy

class VariableJsonTests: XCTestCase {
	override func setUp() {
		super.setUp()
	}
	
	override func tearDown() {
		super.tearDown()
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
