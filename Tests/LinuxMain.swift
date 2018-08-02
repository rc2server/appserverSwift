import XCTest
@testable import servermodelTests
@testable import Rc2AppServerTests

XCTMain([
	testCase(ModelHandlerTests.allTests),
    testCase(FileChangeMonitorTests.allTests),
    testCase(VariableJsonTests.allTests),
    testCase(ComputeCoderTests.allTests),
    testCase(ComputeWorkerTests.allTests),
    testCase(SessionTests.allTests),
])
