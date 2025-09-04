import SwiftUI
import UIKit
import GenMarkCore

public struct MarkdownTextView: UIViewRepresentable {
    public typealias UIViewType = UITextView

    public let attributedText: NSAttributedString
    public init(attributedText: NSAttributedString) {
        self.attributedText = attributedText
    }

    public func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.backgroundColor = .clear
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.isSelectable = true
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.delegate = context.coordinator
        tv.dataDetectorTypes = []
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return tv
    }

    public func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = attributedText
        uiView.linkTextAttributes = [:] // keep style from attributed string
    }
    
    public func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        // Use the proposed width or fall back to a reasonable default
        let width = proposal.width ?? UIScreen.main.bounds.width
        
        // Calculate the height needed for the text at this width
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        
        // Return the width from the proposal and calculated height
        return CGSize(width: width, height: size.height)
    }

    public func makeCoordinator() -> Coordinator { Coordinator() }

    public final class Coordinator: NSObject, UITextViewDelegate {
        public func textView(_ textView: UITextView,
                      shouldInteractWith URL: URL,
                      in characterRange: NSRange,
                      interaction: UITextItemInteraction) -> Bool {
            // Defer link handling to SwiftUI environment via wrapper
            return false
        }
    }
}

public struct OpenURLMarkdownTextView: View {
    @Environment(\.openURL) private var openURL
    private let attributed: NSAttributedString

    public init(attributedText: NSAttributedString) {
        self.attributed = attributedText
    }

    public var body: some View {
        Representable(attributedText: attributed, openURL: openURL)
    }

    private struct Representable: UIViewRepresentable {
        let attributedText: NSAttributedString
        let openURL: OpenURLAction

        func makeCoordinator() -> Coordinator { Coordinator(openURL: openURL) }

        func makeUIView(context: Context) -> UITextView {
            let tv = UITextView()
            tv.backgroundColor = .clear
            tv.isEditable = false
            tv.isScrollEnabled = false
            tv.isSelectable = true
            tv.textContainerInset = .zero
            tv.textContainer.lineFragmentPadding = 0
            tv.delegate = context.coordinator
            tv.dataDetectorTypes = []
            return tv
        }

        func updateUIView(_ uiView: UITextView, context: Context) {
            uiView.attributedText = attributedText
            uiView.linkTextAttributes = [:]
        }
        
        func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
            // Use the proposed width or fall back to a reasonable default
            let width = proposal.width ?? UIScreen.main.bounds.width
            
            // Calculate the height needed for the text at this width
            let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
            
            // Return the width from the proposal and calculated height
            return CGSize(width: width, height: size.height)
        }

        final class Coordinator: NSObject, UITextViewDelegate {
            let openURL: OpenURLAction
            init(openURL: OpenURLAction) { self.openURL = openURL }
            func textView(_ textView: UITextView,
                          shouldInteractWith URL: URL,
                          in characterRange: NSRange,
                          interaction: UITextItemInteraction) -> Bool {
                _ = openURL(URL)
                return false
            }
        }
    }
}

