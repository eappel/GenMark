import UIKit

/// A theme that defines the visual appearance of markdown elements using NSAttributedString attribute dictionaries.
/// This allows for complete transparency in how attributed strings are constructed and customized.
/// 
/// The theme is marked as `@unchecked Sendable` because it contains dictionaries with `Any` values,
/// which cannot automatically conform to Sendable. However, this type is thread-safe when used properly:
/// create once, don't mutate after creation, and ensure all dictionary values are Sendable types.
public struct MarkdownTheme: @unchecked Sendable {
    
    // MARK: - Base Text Attributes
    
    /// Base attributes for regular text (paragraphs)
    /// Should include: .font, .foregroundColor
    public var textAttributes: [NSAttributedString.Key: Any]
    
    /// Attributes for different heading levels
    /// Should include: .font, .foregroundColor  
    public var h1Attributes: [NSAttributedString.Key: Any]
    public var h2Attributes: [NSAttributedString.Key: Any]
    public var h3Attributes: [NSAttributedString.Key: Any]
    public var h4Attributes: [NSAttributedString.Key: Any]
    public var h5Attributes: [NSAttributedString.Key: Any]
    public var h6Attributes: [NSAttributedString.Key: Any]
    
    /// Attributes for code blocks
    /// Should include: .font, .foregroundColor
    public var codeBlockAttributes: [NSAttributedString.Key: Any]
    
    // MARK: - Inline Style Attributes
    
    /// Additional attributes applied to inline code elements
    /// Should include: .font, .backgroundColor
    public var codeAttributes: [NSAttributedString.Key: Any]
    
    /// Additional attributes applied to links  
    /// Should include: .foregroundColor, .underlineStyle
    public var linkAttributes: [NSAttributedString.Key: Any]
    
    /// Additional attributes applied to strikethrough text
    /// Should include: .strikethroughStyle
    public var strikethroughAttributes: [NSAttributedString.Key: Any]
    
    /// Additional attributes applied to emphasis (italic) text
    /// Note: Font modifications are handled separately via font trait methods
    /// This can include other attributes like .foregroundColor if desired
    public var emphasisAttributes: [NSAttributedString.Key: Any]
    
    /// Additional attributes applied to strong (bold) text
    /// Note: Font modifications are handled separately via font trait methods
    /// This can include other attributes like .foregroundColor if desired
    public var strongAttributes: [NSAttributedString.Key: Any]
    
    // MARK: - UI Layout Properties
    
    /// Spacing between block elements (not part of NSAttributedString)
    public var blockSpacing: CGFloat
    
    /// Spacing between paragraphs (not part of NSAttributedString)
    public var paragraphSpacing: CGFloat
    
    /// Background color for code blocks and UI elements (not part of NSAttributedString)
    public var secondaryBackgroundColor: UIColor
    
    /// Color for separators and borders (not part of NSAttributedString)
    public var separatorColor: UIColor
    
    // MARK: - Initializer
    
    public init(
        textAttributes: [NSAttributedString.Key: Any],
        h1Attributes: [NSAttributedString.Key: Any],
        h2Attributes: [NSAttributedString.Key: Any],
        h3Attributes: [NSAttributedString.Key: Any],
        h4Attributes: [NSAttributedString.Key: Any],
        h5Attributes: [NSAttributedString.Key: Any],
        h6Attributes: [NSAttributedString.Key: Any],
        codeBlockAttributes: [NSAttributedString.Key: Any],
        codeAttributes: [NSAttributedString.Key: Any],
        linkAttributes: [NSAttributedString.Key: Any],
        strikethroughAttributes: [NSAttributedString.Key: Any],
        emphasisAttributes: [NSAttributedString.Key: Any] = [:],
        strongAttributes: [NSAttributedString.Key: Any] = [:],
        blockSpacing: CGFloat = 8,
        paragraphSpacing: CGFloat = 4,
        secondaryBackgroundColor: UIColor = .secondarySystemBackground,
        separatorColor: UIColor = .separator
    ) {
        self.textAttributes = textAttributes
        self.h1Attributes = h1Attributes
        self.h2Attributes = h2Attributes
        self.h3Attributes = h3Attributes
        self.h4Attributes = h4Attributes
        self.h5Attributes = h5Attributes
        self.h6Attributes = h6Attributes
        self.codeBlockAttributes = codeBlockAttributes
        self.codeAttributes = codeAttributes
        self.linkAttributes = linkAttributes
        self.strikethroughAttributes = strikethroughAttributes
        self.emphasisAttributes = emphasisAttributes
        self.strongAttributes = strongAttributes
        self.blockSpacing = blockSpacing
        self.paragraphSpacing = paragraphSpacing
        self.secondaryBackgroundColor = secondaryBackgroundColor
        self.separatorColor = separatorColor
    }
    
    // MARK: - Convenience Methods
    
    /// Returns attributes for a specific heading level
    /// - Parameter level: Heading level (1-6)
    /// - Returns: Attribute dictionary for the heading level
    public func headingAttributes(for level: Int) -> [NSAttributedString.Key: Any] {
        switch level {
        case 1: return h1Attributes
        case 2: return h2Attributes
        case 3: return h3Attributes
        case 4: return h4Attributes
        case 5: return h5Attributes
        default: return h6Attributes
        }
    }
}

// MARK: - Default Theme

extension MarkdownTheme {
    /// Default system theme with standard iOS styling
    public static var systemDefault: MarkdownTheme {
        MarkdownTheme(
            textAttributes: [
                .font: UIFont.systemFont(ofSize: 16, weight: .regular),
                .foregroundColor: UIColor.label
            ],
            h1Attributes: [
                .font: UIFont.systemFont(ofSize: 28, weight: .semibold),
                .foregroundColor: UIColor.label
            ],
            h2Attributes: [
                .font: UIFont.systemFont(ofSize: 24, weight: .semibold),
                .foregroundColor: UIColor.label
            ],
            h3Attributes: [
                .font: UIFont.systemFont(ofSize: 20, weight: .semibold),
                .foregroundColor: UIColor.label
            ],
            h4Attributes: [
                .font: UIFont.systemFont(ofSize: 17, weight: .semibold),
                .foregroundColor: UIColor.label
            ],
            h5Attributes: [
                .font: UIFont.systemFont(ofSize: 15, weight: .medium),
                .foregroundColor: UIColor.label
            ],
            h6Attributes: [
                .font: UIFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: UIColor.label
            ],
            codeBlockAttributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                .foregroundColor: UIColor.label
            ],
            codeAttributes: [
                .font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular),
                .backgroundColor: UIColor.secondarySystemBackground.withAlphaComponent(0.3)
            ],
            linkAttributes: [
                .foregroundColor: UIColor.link,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ],
            strikethroughAttributes: [
                .strikethroughStyle: NSUnderlineStyle.single.rawValue
            ]
        )
    }
}