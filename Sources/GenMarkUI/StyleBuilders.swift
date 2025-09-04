import Foundation

// Result builders (stubs)

@resultBuilder
public enum MarkdownStyleBuilder {
    public static func buildBlock(_ components: MarkdownStyle...) -> MarkdownStyle {
        var style = MarkdownStyle()
        components.forEach { style.merge($0) }
        return style
    }
}

@resultBuilder
public enum MarkdownRendererBuilder {
    public static func buildBlock(_ components: MarkdownRenderOverrides...) -> MarkdownRenderOverrides {
        var overrides = MarkdownRenderOverrides()
        components.forEach { overrides.merge($0) }
        return overrides
    }
}

public struct MarkdownStyle: Sendable {
    public init() {}
    mutating public func merge(_ other: MarkdownStyle) {}
    public static var `default`: MarkdownStyle { MarkdownStyle() }
}

public struct MarkdownRenderOverrides: Sendable {
    public init() {}
    mutating public func merge(_ other: MarkdownRenderOverrides) {}
    public static var empty: MarkdownRenderOverrides { MarkdownRenderOverrides() }
}

