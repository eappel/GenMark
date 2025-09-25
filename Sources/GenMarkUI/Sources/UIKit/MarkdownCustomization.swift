import SwiftUI
import GenMarkCore

public typealias MarkdownInlineAttributeAdjuster = @MainActor (
    InlineNode,
    [NSAttributedString.Key: Any]
) -> [NSAttributedString.Key: Any]?

public typealias MarkdownInlineRenderer = @MainActor (
    InlineNode,
    [NSAttributedString.Key: Any],
    @MainActor ([NSAttributedString.Key: Any]?) -> NSAttributedString // render block, pass nil attributes to use default
) -> NSAttributedString

public typealias MarkdownBlockRenderer = @MainActor (
    BlockNode,
    MarkdownTheme
) -> AnyView?

public enum MarkdownCustomizers {
    public static let inlineNone: MarkdownInlineAttributeAdjuster = { _, _ in nil }
    public static let blockNone: MarkdownBlockRenderer = { _, _ in nil }

    public static func combineInline(_ customizers: MarkdownInlineAttributeAdjuster...) -> MarkdownInlineAttributeAdjuster {
        { node, attributes in
            for customizer in customizers {
                if let modified = customizer(node, attributes) {
                    return modified
                }
            }
            return nil
        }
    }

    public static func combineBlock(_ customizers: MarkdownBlockRenderer...) -> MarkdownBlockRenderer {
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
