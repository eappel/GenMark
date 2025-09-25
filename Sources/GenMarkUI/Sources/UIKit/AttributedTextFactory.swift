import UIKit
import GenMarkCore

/// Factory for creating NSAttributedString instances from inline markdown nodes
/// Uses theme attributes and optional customization hooks.
@MainActor
public struct AttributedTextFactory {
    let theme: MarkdownTheme
    let inlineAttributeAdjuster: MarkdownInlineAttributeAdjuster?
    let inlineRenderer: MarkdownInlineRenderer?

    public init(
        theme: MarkdownTheme = .systemDefault,
        inlineAttributeAdjuster: MarkdownInlineAttributeAdjuster? = nil,
        inlineRenderer: MarkdownInlineRenderer? = nil
    ) {
        self.theme = theme
        self.inlineAttributeAdjuster = inlineAttributeAdjuster
        self.inlineRenderer = inlineRenderer
    }
    
    /// Creates an attributed string from inline nodes
    /// - Parameters:
    ///   - inlines: The inline nodes to render
    ///   - baseAttributes: Base attributes to use, defaults to theme.textAttributes if nil
    /// - Returns: Fully attributed string
    public func make(
        from inlines: [InlineNode],
        baseAttributes: [NSAttributedString.Key: Any]? = nil
    ) -> NSAttributedString {
        let base = baseAttributes ?? theme.textAttributes
        return renderInlines(inlines, attributes: base)
    }
    
    /// Creates an attributed string with a specific base font
    /// - Parameters:
    ///   - inlines: The inline nodes to render
    ///   - baseFont: The base font to use
    /// - Returns: Fully attributed string
    public func make(
        from inlines: [InlineNode],
        baseFont: UIFont
    ) -> NSAttributedString {
        var base = theme.textAttributes
        base[.font] = baseFont
        return renderInlines(inlines, attributes: base)
    }
    
    // MARK: - Rendering Helpers
    
    private func renderInline(
        _ inline: InlineNode,
        attributes: [NSAttributedString.Key: Any]
    ) -> NSAttributedString {
        let plan = makeRenderPlan(for: inline, attributes: attributes)
        guard let inlineRenderer else {
            return plan.render(plan.attributes)
        }
        return inlineRenderer(inline, plan.attributes) { overrideAttrs in
            let attrs = overrideAttrs ?? plan.attributes
            return plan.render(attrs)
        }
    }
    
    private func makeRenderPlan(
        for inline: InlineNode,
        attributes: [NSAttributedString.Key: Any]
    ) -> InlineRenderPlan {
        switch inline {
        case .text(let text):
            let finalAttrs = applyCustomizationIfNecessary(to: inline, attributes: attributes)
            return InlineRenderPlan(attributes: finalAttrs) { attrs in
                NSAttributedString(string: text, attributes: attrs)
            }
            
        case .emphasis(let children):
            let emphasisBase = applyEmphasis(to: attributes)
            let emphasisAttrs = applyCustomizationIfNecessary(to: inline, attributes: emphasisBase)
            return InlineRenderPlan(attributes: emphasisAttrs) { childAttrs in
                renderInlines(children, attributes: childAttrs)
            }
            
        case .strong(let children):
            let strongBase = applyStrong(to: attributes)
            let strongAttrs = applyCustomizationIfNecessary(to: inline, attributes: strongBase)
            return InlineRenderPlan(attributes: strongAttrs) { childAttrs in
                renderInlines(children, attributes: childAttrs)
            }
            
        case .strikethrough(let children):
            let strikeBase = mergeAttributes(base: attributes, adding: theme.strikethroughAttributes)
            let strikethroughAttrs = applyCustomizationIfNecessary(to: inline, attributes: strikeBase)
            return InlineRenderPlan(attributes: strikethroughAttrs) { childAttrs in
                renderInlines(children, attributes: childAttrs)
            }
            
        case .code(let code):
            let codeAttrs = mergeAttributes(base: attributes, adding: theme.codeAttributes)
            let finalAttrs = applyCustomizationIfNecessary(to: inline, attributes: codeAttrs)
            return InlineRenderPlan(attributes: finalAttrs) { attrs in
                NSAttributedString(string: code, attributes: attrs)
            }
            
        case .link(let url, _, let children):
            let defaultLinkAttrs = mergeAttributes(base: attributes, adding: theme.linkAttributes)
            let customizedLinkAttrs = applyCustomizationIfNecessary(to: inline, attributes: defaultLinkAttrs)
            return InlineRenderPlan(attributes: customizedLinkAttrs) { childAttrs in
                let rendered = renderInlines(children, attributes: childAttrs)
                if rendered.length > 0 {
                    let range = NSRange(location: 0, length: rendered.length)
                    rendered.addAttribute(.link, value: url, range: range)
                }
                return rendered
            }
            
        case .image(let url, let alt):
            let altText = alt ?? url.absoluteString
            let finalAttrs = applyCustomizationIfNecessary(to: inline, attributes: attributes)
            return InlineRenderPlan(attributes: finalAttrs) { attrs in
                NSAttributedString(string: altText, attributes: attrs)
            }
            
        case .softBreak:
            let finalAttrs = applyCustomizationIfNecessary(to: inline, attributes: attributes)
            return InlineRenderPlan(attributes: finalAttrs) { attrs in
                NSAttributedString(string: " ", attributes: attrs)
            }
            
        case .lineBreak:
            let finalAttrs = applyCustomizationIfNecessary(to: inline, attributes: attributes)
            return InlineRenderPlan(attributes: finalAttrs) { attrs in
                NSAttributedString(string: "\n", attributes: attrs)
            }
        }
    }
    
    // MARK: - Attribute Manipulation Helpers
    
    private func renderInlines(
        _ inlines: [InlineNode],
        attributes: [NSAttributedString.Key: Any]
    ) -> NSMutableAttributedString {
        let result = NSMutableAttributedString()
        for inline in inlines {
            let rendered = renderInline(inline, attributes: attributes)
            result.append(rendered)
        }
        return result
    }
    
    private func mergeAttributes(
        base: [NSAttributedString.Key: Any],
        adding: [NSAttributedString.Key: Any]
    ) -> [NSAttributedString.Key: Any] {
        var result = base
        for (key, value) in adding {
            result[key] = value
        }
        return result
    }
    
    private func applyEmphasis(
        to attributes: [NSAttributedString.Key: Any]
    ) -> [NSAttributedString.Key: Any] {
        var result = attributes
        if let font = attributes[.font] as? UIFont {
            result[.font] = addItalicTrait(to: font)
        }
        return mergeAttributes(base: result, adding: theme.emphasisAttributes)
    }
    
    private func applyStrong(
        to attributes: [NSAttributedString.Key: Any]
    ) -> [NSAttributedString.Key: Any] {
        var result = attributes
        if let font = attributes[.font] as? UIFont {
            result[.font] = addBoldTrait(to: font)
        }
        return mergeAttributes(base: result, adding: theme.strongAttributes)
    }
    
    private func addItalicTrait(to font: UIFont) -> UIFont {
        let existingTraits = font.fontDescriptor.symbolicTraits
        guard let descriptor = font.fontDescriptor.withSymbolicTraits(existingTraits.union(.traitItalic)) else {
            return font
        }
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }
    
    private func addBoldTrait(to font: UIFont) -> UIFont {
        let existingTraits = font.fontDescriptor.symbolicTraits
        guard let descriptor = font.fontDescriptor.withSymbolicTraits(existingTraits.union(.traitBold)) else {
            return font
        }
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }
    
    private func applyCustomizationIfNecessary(
        to node: InlineNode,
        attributes: [NSAttributedString.Key: Any]
    ) -> [NSAttributedString.Key: Any] {
        guard let inlineAttributeAdjuster else { return attributes }
        return inlineAttributeAdjuster(node, attributes) ?? attributes
    }
}

private struct InlineRenderPlan {
    let attributes: [NSAttributedString.Key: Any]
    let render: ([NSAttributedString.Key: Any]) -> NSAttributedString
}
