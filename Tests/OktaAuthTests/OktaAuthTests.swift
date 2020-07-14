import XCTest
@testable import OktaAuth

final class OktaAuthTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(OktaAuth().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
