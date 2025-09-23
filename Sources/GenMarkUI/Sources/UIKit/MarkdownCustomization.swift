import SwiftUI
import GenMarkCore

public typealias MarkdownInlineCustomizer = @MainActor (
    InlineNode,
    [NSAttributedString.Key: Any]
) -> [NSAttributedString.Key: Any]?

public typealias MarkdownBlockCustomizer = @MainActor (
    BlockNode,
    MarkdownTheme
) -> AnyView?

public enum MarkdownCustomizers {
    public static let inlineNone: MarkdownInlineCustomizer = { _, _ in nil }
    public static let blockNone: MarkdownBlockCustomizer = { _, _ in nil }

    public static func combineInline(_ customizers: MarkdownInlineCustomizer...) -> MarkdownInlineCustomizer {
        { node, attributes in
            for customizer in customizers {
                if let modified = customizer(node, attributes) {
                    return modified
                }
            }
            return nil
        }
    }

    public static func combineBlock(_ customizers: MarkdownBlockCustomizer...) -> MarkdownBlockCustomizer {
        { node, theme in
            for customizer in customizers {
                if let view = customizer(node, theme) {
                    return view
                }
            }
            return nil
        }
    }
}
