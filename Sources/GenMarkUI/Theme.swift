import UIKit

public struct MarkdownTheme: Sendable {
    public var foreground: UIColor
    public var secondaryForeground: UIColor
    public var background: UIColor
    public var secondaryBackground: UIColor
    public var separator: UIColor
    public var link: UIColor

    // Typography (explicit sizes)
    public var bodyFont: UIFont = .systemFont(ofSize: 16, weight: .regular)
    public var codeInlineFont: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    public var codeBlockFont: UIFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
    public var h1: UIFont = .systemFont(ofSize: 28, weight: .semibold)
    public var h2: UIFont = .systemFont(ofSize: 24, weight: .semibold)
    public var h3: UIFont = .systemFont(ofSize: 20, weight: .semibold)
    public var h4: UIFont = .systemFont(ofSize: 17, weight: .semibold)
    public var h5: UIFont = .systemFont(ofSize: 15, weight: .medium)
    public var h6: UIFont = .systemFont(ofSize: 13, weight: .medium)

    // Spacing
    public var blockSpacing: CGFloat = 8
    public var paragraphSpacing: CGFloat = 4

    public static var systemDefault: MarkdownTheme {
        MarkdownTheme(
            foreground: .label,
            secondaryForeground: .secondaryLabel,
            background: .systemBackground,
            secondaryBackground: .secondarySystemBackground,
            separator: .separator,
            link: .link
        )
    }
}

