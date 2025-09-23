import SwiftUI
import UIKit
import GenMarkCore

public struct MarkdownTextView: View {
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
            let textView = LinkTextView()
            context.coordinator.prepare(textView: textView)
            return textView
        }

        func updateUIView(_ uiView: UITextView, context: Context) {
            let identifier = ObjectIdentifier(attributedText)
            if context.coordinator.lastRenderedIdentifier != identifier {
                uiView.attributedText = attributedText
                context.coordinator.lastRenderedIdentifier = identifier
            }
            // Ensure our per-range attributes control link appearance
            if uiView.linkTextAttributes.isEmpty == false {
                uiView.linkTextAttributes = [:]
            }
        }
        
        func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
            guard let width = proposal.width else { return nil }
            let key = SizeCache.Key(width: width, attributedIdentifier: ObjectIdentifier(attributedText))
            if let cached = Self.sizeCache.size(for: key) {
                return cached
            }
            let measured = uiView.sizeThatFits(.init(width: width, height: .greatestFiniteMagnitude))
            Self.sizeCache.insert(measured, for: key)
            return measured
        }

        final class Coordinator: NSObject, UITextViewDelegate, LinkTextViewDelegate {
            let openURL: OpenURLAction
            var lastRenderedIdentifier: ObjectIdentifier?

            init(openURL: OpenURLAction) {
                self.openURL = openURL
            }

            func prepare(textView: LinkTextView) {
                textView.backgroundColor = .clear
                textView.isEditable = false
                textView.isScrollEnabled = false
                textView.isSelectable = true
                textView.delaysContentTouches = false
                textView.textContainerInset = .zero
                textView.textContainer.lineFragmentPadding = 0
                textView.dataDetectorTypes = []
                textView.adjustsFontForContentSizeCategory = false
                textView.linkTextAttributes = [:]
                textView.delegate = self
                textView.linkDelegate = self
                textView.openURL = openURL
            }

            func textView(
                _ textView: UITextView,
                shouldInteractWith URL: URL,
                in characterRange: NSRange
            ) -> Bool {
                // hanlded by LinkTextViewDelegate
                return false
            }
            
            func linkTextView(_ textView: LinkTextView, didTapLink url: URL) {
                openURL(url)
            }
        }

        private static let sizeCache = SizeCache()

        private final class SizeCache {
            private var storage: [Key: CGSize] = [:]
            private let lock = NSLock()
            private let limit = 512

            func size(for key: Key) -> CGSize? {
                lock.lock()
                defer { lock.unlock() }
                return storage[key]
            }

            func insert(_ size: CGSize, for key: Key) {
                lock.lock()
                defer { lock.unlock() }
                if storage.count >= limit, let firstKey = storage.keys.first {
                    storage.removeValue(forKey: firstKey)
                }
                storage[key] = size
            }

            struct Key: Hashable {
                let widthBits: UInt64
                let attributedIdentifier: ObjectIdentifier

                init(width: CGFloat, attributedIdentifier: ObjectIdentifier) {
                    self.widthBits = Double(width).bitPattern
                    self.attributedIdentifier = attributedIdentifier
                }
            }
        }
    }
}

// Overrides link handling behavior with a tap gesture to remove delay in UITextView native handling
class LinkTextView: UITextView, UIGestureRecognizerDelegate {
    var openURL: OpenURLAction?
    
    weak var linkDelegate: LinkTextViewDelegate?
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapRecognizer.delegate = self
        self.addGestureRecognizer(tapRecognizer)
    }

    @objc
    private func handleTap(_ recognizer: UITapGestureRecognizer) {
        let point = recognizer.location(in: self)
        if let textRange = characterRange(at: point) {
            let startIndex = offset(from: beginningOfDocument, to: textRange.start)
            handleLink(at: startIndex, in: self)
            return
        }
    }
    
    private func handleLink(at index: Int, in textView: UITextView) {
        guard index >= 0, index < textView.attributedText.length else { return }
        var effectiveRange = NSRange(location: 0, length: 0)
        let attrs = textView.attributedText.attributes(at: index, effectiveRange: &effectiveRange)
        guard let value = attrs[.link] else { return }
        if let url = value as? URL {
            openURL?(url)
        } else if let str = value as? String, let url = URL(string: str) {
            openURL?(url)
        }
    }
    
    // Allow our gesture recognizer to work simultaneously with built-in ones
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return true
    }
}

protocol LinkTextViewDelegate: AnyObject {
    @MainActor func linkTextView(_ textView: LinkTextView, didTapLink url: URL)
}
