import SwiftUI
import UIKit
import CoreText
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
            let textView = UITextView()
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
            let measured = measure(attributedText: attributedText, width: width)
            Self.sizeCache.insert(measured, for: key)
            return measured
        }

        private func measure(attributedText: NSAttributedString, width: CGFloat) -> CGSize {
            guard attributedText.length > 0 else {
                return CGSize(width: width, height: 0)
            }

            let framesetter = CTFramesetterCreateWithAttributedString(attributedText as CFAttributedString)
            let constraint = CGSize(width: width, height: .greatestFiniteMagnitude)
            var fitRange = CFRange()
            var suggested = CTFramesetterSuggestFrameSizeWithConstraints(
                framesetter,
                CFRange(location: 0, length: attributedText.length),
                nil,
                constraint,
                &fitRange
            )
            if suggested.width.isFinite == false { suggested.width = width }
            if suggested.height.isFinite == false { suggested.height = 0 }

            // Clamp width to constraint; include min positive height to avoid zero-height rows
            suggested.width = min(suggested.width, width)
            let adjustedHeight = max(ceil(suggested.height), 0)
            return CGSize(width: ceil(suggested.width), height: adjustedHeight)
        }

        final class Coordinator: NSObject, UITextViewDelegate {
            let openURL: OpenURLAction
            var lastRenderedIdentifier: ObjectIdentifier?

            init(openURL: OpenURLAction) {
                self.openURL = openURL
            }

            func prepare(textView: UITextView) {
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
            }

            func textView(
                _ textView: UITextView,
                shouldInteractWith URL: URL,
                in characterRange: NSRange
            ) -> Bool {
                openURL(URL)
                return false
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
