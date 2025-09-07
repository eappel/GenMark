import SwiftUI
import UIKit
import GenMarkCore

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
            tv.adjustsFontForContentSizeCategory = true
            return tv
        }

        func updateUIView(_ uiView: UITextView, context: Context) {
            uiView.attributedText = attributedText
            // We clear UITextView's global linkTextAttributes so that the
            // per-range attributes embedded in our NSAttributedString (via
            // AttributedTextFactory + theme.linkAttributes and the `.link`
            // attribute) fully control link appearance. If this is left
            // non-empty, UIKit's defaults can override our color/underline
            // styling and ignore theme customizations. Setting it to empty
            // keeps links interactive while respecting our attributed text.
            uiView.linkTextAttributes = [:]
        }
        
        func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
            // Respect proposed width; if nil, let SwiftUI drive sizing
            guard let width = proposal.width else { return nil }
            let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
            return CGSize(width: width, height: size.height)
        }

        final class Coordinator: NSObject, UITextViewDelegate {
            let openURL: OpenURLAction
            init(openURL: OpenURLAction) { self.openURL = openURL }
            func textView(
                _ textView: UITextView,
                shouldInteractWith URL: URL,
                in characterRange: NSRange
            ) -> Bool {
                openURL(URL)
                return false
            }
        }
    }
}
