import AppKit
import Down

public struct MarkdownRenderer {
    public init() {}

    public func render(_ markdown: String) throws -> NSAttributedString {
        try Down(markdownString: markdown).toAttributedString(
            .default,
            stylesheet: "body { font: -apple-system-body; }"
        )
    }
}
