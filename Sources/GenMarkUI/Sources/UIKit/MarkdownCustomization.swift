import UIKit
import SwiftUI
import GenMarkCore

/// A container for customization closures that modify the appearance of markdown nodes
public struct MarkdownCustomization: Sendable {
    /// Customizes the attributes for inline nodes
    /// Parameters:
    /// - node: The inline node being rendered
    /// - attributes: The default attributes that would be applied
    /// Returns: Modified attributes dictionary, or nil to use defaults
    public let inlineCustomizer: @MainActor (InlineNode, [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any]?
    
    /// Customizes the view for block nodes
    /// Parameters:
    /// - node: The block node being rendered
    /// - defaultView: The default view that would be rendered
    /// Returns: A custom view to replace the default, or nil to use default
    public let blockCustomizer: @MainActor (BlockNode, MarkdownTheme) -> AnyView?
    
    public init(
        inlineCustomizer: @escaping @MainActor (InlineNode, [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any]? = { _, _ in nil },
        blockCustomizer: @escaping @MainActor (BlockNode, MarkdownTheme) -> AnyView? = { _, _ in nil }
    ) {
        self.inlineCustomizer = inlineCustomizer
        self.blockCustomizer = blockCustomizer
    }
    
    /// Default customization that doesn't modify anything
    public static let none = MarkdownCustomization()
}

// MARK: - Convenience Initializers

extension MarkdownCustomization {
    /// Creates a customization that only modifies inline nodes
    public static func inline(
        _ customizer: @escaping @MainActor (InlineNode, [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any]?
    ) -> MarkdownCustomization {
        MarkdownCustomization(inlineCustomizer: customizer)
    }
    
    /// Creates a customization that only modifies block nodes
    public static func block(
        _ customizer: @escaping @MainActor (BlockNode, MarkdownTheme) -> AnyView?
    ) -> MarkdownCustomization {
        MarkdownCustomization(blockCustomizer: customizer)
    }
    
    /// Combines multiple customizations, with later ones taking precedence
    public static func combine(_ customizations: MarkdownCustomization...) -> MarkdownCustomization {
        MarkdownCustomization(
            inlineCustomizer: { node, attrs in
                for customization in customizations {
                    if let modified = customization.inlineCustomizer(node, attrs) {
                        return modified
                    }
                }
                return nil
            },
            blockCustomizer: { node, theme in
                for customization in customizations {
                    if let view = customization.blockCustomizer(node, theme) {
                        return view
                    }
                }
                return nil
            }
        )
    }
}
