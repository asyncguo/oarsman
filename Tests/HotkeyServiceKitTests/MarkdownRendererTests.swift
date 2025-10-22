import XCTest
@testable import HotkeyServiceKit

final class MarkdownRendererTests: XCTestCase {
    func testRendersPlainText() throws {
        let renderer = MarkdownRenderer()
        let result = try renderer.render("Hello, world!")
        XCTAssertTrue(result.string.contains("Hello, world!"))
    }
}
