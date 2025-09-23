import UIKit
import GenMarkCore

/// Factory for creating NSAttributedString instances from inline markdown nodes
/// Uses the theme's attribute dictionaries directly for transparent and traceable construction
@MainActor
public struct AttributedTextFactory {
    let theme: MarkdownTheme
    let inlineCustomizer: MarkdownInlineCustomizer?

    public init(
        theme: MarkdownTheme = .systemDefault,
        inlineCustomizer: MarkdownInlineCustomizer? = nil
    ) {
        self.theme = theme
        self.inlineCustomizer = inlineCustomizer
    }
    
    /// Creates an attributed string from inline nodes
    /// - Parameters:
    ///   - inlines: The inline nodes to render
    ///   - baseAttributes: Base attributes to use, defaults to theme.textAttributes if nil
    /// - Returns: Fully attributed string
    public func make(from inlines: [InlineNode], baseAttributes: [NSAttributedString.Key: Any]? = nil) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let base = baseAttributes ?? theme.textAttributes
        appendInlines(inlines, to: result, attributes: base)
        return result
    }
    
    /// Creates an attributed string with a specific base font (for headings)
    /// - Parameters:
    ///   - inlines: The inline nodes to render
    ///   - baseFont: The base font to use
    /// - Returns: Fully attributed string
    public func make(from inlines: [InlineNode], baseFont: UIFont) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var base = theme.textAttributes
        base[.font] = baseFont
        appendInlines(inlines, to: result, attributes: base)
        return result
    }
    
    // MARK: - Private Implementation
    
    /// Recursively processes inline nodes and appends them to the result
    /// - Parameters:
    ///   - inlines: Inline nodes to process
    ///   - result: Mutable attributed string to append to
    ///   - attributes: Current attribute context
    private func appendInlines(_ inlines: [InlineNode], to result: NSMutableAttributedString, attributes: [NSAttributedString.Key: Any]) {
        for inline in inlines {
            switch inline {
            case .text(let text):
                let finalAttrs = applyCustomization(to: inline, defaultAttributes: attributes)
                result.append(NSAttributedString(string: text, attributes: finalAttrs))
                
            case .emphasis(let children):
                // Start with theme emphasis, allow customization to override for this wrapper
                let emphasisBase = applyEmphasis(to: attributes)
                let emphasisAttrs = applyCustomization(to: .emphasis(children), defaultAttributes: emphasisBase)
                appendInlines(children, to: result, attributes: emphasisAttrs)
                
            case .strong(let children):
                // Start with theme strong, allow customization to override for this wrapper
                let strongBase = applyStrong(to: attributes)
                let strongAttrs = applyCustomization(to: .strong(children), defaultAttributes: strongBase)
                appendInlines(children, to: result, attributes: strongAttrs)
                
            case .strikethrough(let children):
                // Start with theme strikethrough, allow customization to override for this wrapper
                let strikeBase = mergeAttributes(base: attributes, adding: theme.strikethroughAttributes)
                let strikethroughAttrs = applyCustomization(to: .strikethrough(children), defaultAttributes: strikeBase)
                appendInlines(children, to: result, attributes: strikethroughAttrs)
                
            case .code(let code):
                let codeAttrs = mergeAttributes(base: attributes, adding: theme.codeAttributes)
                let finalAttrs = applyCustomization(to: inline, defaultAttributes: codeAttrs)
                result.append(NSAttributedString(string: code, attributes: finalAttrs))
                
            case .link(let url, let title, let children):
                // Start from theme link attributes, then allow customization to override
                let defaultLinkAttrs = mergeAttributes(base: attributes, adding: theme.linkAttributes)
                let customizedLinkAttrs = applyCustomization(
                    to: .link(url: url, title: title, children: children),
                    defaultAttributes: defaultLinkAttrs
                )

                let startRange = result.length
                appendInlines(children, to: result, attributes: customizedLinkAttrs)
                let range = NSRange(location: startRange, length: result.length - startRange)
                result.addAttribute(.link, value: url, range: range)
                
            case .image(let url, let alt):
                // For now, render alt text - image loading will be handled separately
                let altText = alt ?? url.absoluteString
                let finalAttrs = applyCustomization(to: inline, defaultAttributes: attributes)
                result.append(NSAttributedString(string: altText, attributes: finalAttrs))
                
            case .softBreak:
                let finalAttrs = applyCustomization(to: inline, defaultAttributes: attributes)
                result.append(NSAttributedString(string: " ", attributes: finalAttrs))
                
            case .lineBreak:
                let finalAttrs = applyCustomization(to: inline, defaultAttributes: attributes)
                result.append(NSAttributedString(string: "\n", attributes: finalAttrs))
                
            
            }
        }
    }
    
    // MARK: - Attribute Manipulation Helpers
    
    /// Merges two attribute dictionaries, with the adding dictionary taking precedence
    /// - Parameters:
    ///   - base: Base attributes
    ///   - adding: Additional attributes to merge in
    /// - Returns: Merged attribute dictionary
    private func mergeAttributes(base: [NSAttributedString.Key: Any], adding: [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any] {
        var result = base
        for (key, value) in adding {
            result[key] = value
        }
        return result
    }
    
    /// Applies emphasis (italic) to the given attributes
    /// This modifies the font to add italic traits while preserving other font characteristics
    /// - Parameter attributes: Base attributes
    /// - Returns: Attributes with emphasis applied
    private func applyEmphasis(to attributes: [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any] {
        var result = attributes
        
        // Apply font trait modification if there's a font
        if let font = attributes[.font] as? UIFont {
            result[.font] = addItalicTrait(to: font)
        }
        
        // Merge any additional emphasis attributes from theme
        return mergeAttributes(base: result, adding: theme.emphasisAttributes)
    }
    
    /// Applies strong (bold) to the given attributes
    /// This modifies the font to add bold traits while preserving other font characteristics
    /// - Parameter attributes: Base attributes
    /// - Returns: Attributes with strong applied
    private func applyStrong(to attributes: [NSAttributedString.Key: Any]) -> [NSAttributedString.Key: Any] {
        var result = attributes
        
        // Apply font trait modification if there's a font
        if let font = attributes[.font] as? UIFont {
            result[.font] = addBoldTrait(to: font)
        }
        
        // Merge any additional strong attributes from theme
        return mergeAttributes(base: result, adding: theme.strongAttributes)
    }
    
    // MARK: - Font Trait Helpers
    
    /// Adds italic trait to a font while preserving existing traits
    private func addItalicTrait(to font: UIFont) -> UIFont {
        let existingTraits = font.fontDescriptor.symbolicTraits
        guard let descriptor = font.fontDescriptor.withSymbolicTraits(existingTraits.union(.traitItalic)) else {
            return font
        }
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }
    
    /// Adds bold trait to a font while preserving existing traits
    private func addBoldTrait(to font: UIFont) -> UIFont {
        let existingTraits = font.fontDescriptor.symbolicTraits
        guard let descriptor = font.fontDescriptor.withSymbolicTraits(existingTraits.union(.traitBold)) else {
            return font
        }
        return UIFont(descriptor: descriptor, size: font.pointSize)
    }
    
    /// Applies customization to the given attributes
    /// - Parameters:
    ///   - node: The inline node being customized
    ///   - defaultAttributes: The default attributes before customization
    /// - Returns: Customized attributes or default if no customization applied
    private func applyCustomization(
        to node: InlineNode,
        defaultAttributes: [NSAttributedString.Key: Any]
    ) -> [NSAttributedString.Key: Any] {
        guard let inlineCustomizer else { return defaultAttributes }
        return inlineCustomizer(node, defaultAttributes) ?? defaultAttributes
    }
}
