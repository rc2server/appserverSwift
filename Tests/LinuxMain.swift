import XCTest
@testable import servermodelTests
@testable import Rc2AppServerTests

XCTMain([
    testCase(FileChangeMonitorTests.allTests),
    testCase(VariableJsonTests.allTests)
])
