import SwiftUI
import GenMarkUI
import GenMarkCore
import UIKit

// Helper extension to extract inline content from block nodes
extension BlockNode {
    var inlineContent: [InlineNode] {
        switch self {
        case .heading(_, let inlines):
            return inlines
        case .paragraph(let inlines):
            return inlines
        default:
            return []
        }
    }
}

struct CustomizationExampleView: View {
    let markdown = """
    # Custom Heading
    This is a **bold** paragraph with some *emphasized* text and `inline code`.
    
    > A blockquote that can be customized
    
    - List item 1
    - List item 2 with **bold**
    
    ```swift
    let code = "This is a code block"
    ```
    
    [Custom Link](https://example.com)
    """
    
    @ViewBuilder
    private var inlineCustomizedView: some View {
        MarkdownView(
            markdown,
            inlineAttributeAdjuster: { node, attrs in
                // Make all code green
                if case .code = node {
                    var newAttrs = attrs
                    newAttrs[.foregroundColor] = UIColor.systemGreen
                    newAttrs[.backgroundColor] = UIColor.systemGreen.withAlphaComponent(0.1)
                    return newAttrs
                }
                // Make links red and not underlined
                if case .link = node {
                    var newAttrs = attrs
//                    newAttrs[.foregroundColor] = UIColor.systemRed
                    newAttrs[.attachment] = NSTextAttachment(image: UIImage(systemName: "checkmark")!)
//                    newAttrs[.underlineStyle] = nil
                    return newAttrs
                }
                // Make strong text also italic
                if case .strong = node {
                    var newAttrs = attrs
                    if let font = attrs[.font] as? UIFont {
                        let descriptor = font.fontDescriptor
                            .withSymbolicTraits([.traitBold, .traitItalic]) ?? font.fontDescriptor
                        newAttrs[.font] = UIFont(descriptor: descriptor, size: font.pointSize)
                    }
                    return newAttrs
                }
                return nil
            },
            blockRenderer: { node, _ in
                if case .table = node {
                    return AnyView(Rectangle().fill(.orange))
                }
                return nil
            }
        )
    }

    @ViewBuilder
    private var inlineRendererView: some View {
        MarkdownView(
            markdown,
            inlineRenderer: { node, attributes, render in
                guard case let .link(url, _, _) = node else {
                    return render(nil)
                }

                let renderer = ImageRenderer(content: MySwiftUIView())

                guard let image = renderer.uiImage else {
                    return render(nil)
                }

                let attachment = image.asTextAttachment()
                if let font = attributes[.font] as? UIFont {
                    attachment.bounds = CGRect(
                        x: 0,
                        y: font.descender,
                        width: image.size.width,
                        height: image.size.height
                    )
                }

                var labelAttributes = attributes
                labelAttributes[.foregroundColor] = UIColor.systemPurple
                let label = render(labelAttributes)

                let composite = NSMutableAttributedString(attributedString: NSAttributedString(attachment: attachment))
                composite.append(NSAttributedString(string: " "))
                composite.append(label)
                let linkRange = NSRange(location: 0, length: composite.length)
                composite.addAttribute(.link, value: url, range: linkRange)
                return composite
            }
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Default Rendering")
                    .font(.headline)
                MarkdownView(markdown)
                    .border(Color.gray)
                
                Spacer().frame(height: 10)
                
                Text("With Inline Customization")
                    .font(.headline)
                inlineCustomizedView
                    .border(Color.gray)
                
                Spacer().frame(height: 10)

                Text("With Inline Middleware")
                    .font(.headline)
                inlineRendererView
                    .border(Color.gray)
                
                Spacer().frame(height: 10)

                Text("With Block Customization")
                    .font(.headline)
                MarkdownView(
                    markdown,
                    blockRenderer: { node, theme in
                        // Custom blockquote rendering
                        if case .blockQuote(_) = node {
                            return AnyView(
                                HStack {
                                    Rectangle()
                                        .fill(Color.blue)
                                        .frame(width: 4)
                                    VStack(alignment: .leading) {
                                        Text("Custom styled blockquote")
                                            .italic()
                                            .foregroundColor(.blue)
                                        Text("With custom blue theme")
                                            .font(.caption)
                                            .foregroundColor(.blue.opacity(0.8))
                                    }
                                    .padding(.leading, 8)
                                }
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                            )
                        }
                        // Custom code block rendering
                        if case .codeBlock(let language, let code) = node {
                            return AnyView(
                                VStack(alignment: .leading, spacing: 0) {
                                    if let lang = language {
                                        Text(lang)
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(Color.purple)
                                            .cornerRadius(4)
                                            .padding()
                                    }
                                    Text(code)
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(.white)
                                        .padding(.horizontal)
                                        .padding(.bottom)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .background(Color.black)
                                .cornerRadius(8)
                            )
                        }
                        return nil
                    }
                )
                .border(Color.gray)
                
                Spacer().frame(height: 10)
                
                Text("Combined Customizations")
                    .font(.headline)
                MarkdownView(
                    markdown,
                    inlineAttributeAdjuster: { node, attrs in
                        // Purple emphasis
                        if case .emphasis = node {
                            var newAttrs = attrs
                            newAttrs[.foregroundColor] = UIColor.systemPurple
                            return newAttrs
                        }
                        return nil
                    },
                    blockRenderer: { node, theme in
                        // Custom heading with gradient
                        if case .heading(let level, _) = node {
                            // Extract text content for the gradient heading
                            let factory = AttributedTextFactory(theme: theme)
                            let headingAttrs = theme.headingAttributes(for: level)
                            let attr = factory.make(from: node.inlineContent, baseAttributes: headingAttrs)
                            return AnyView(
                                Text(attr.string)
                                    .font(.system(size: CGFloat(32 - level * 4), weight: .bold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .padding(.vertical, 4)
                            )
                        }
                        return nil
                    }
                )
                .border(Color.gray)
            }
            .padding()
        }
        .navigationTitle("Customization Examples")
    }
}

// Define a SwiftUI View you want to convert
struct MySwiftUIView: View {
    var body: some View {
        Text("1")
            .padding(6)
            .font(.caption)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.teal)
            }
    }
}

extension UIImage {
    func asTextAttachment() -> NSTextAttachment {
        let textAttachment = NSTextAttachment()
        textAttachment.image = self
        return textAttachment
    }
}

#Preview {
    NavigationView {
        CustomizationExampleView()
    }
}
