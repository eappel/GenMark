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
            let textView = UITextView()
            context.coordinator.prepare(textView: textView)
            return textView
        }

        func updateUIView(_ uiView: UITextView, context: Context) {
            uiView.attributedText = attributedText
            // Ensure our per-range attributes control link appearance
            uiView.linkTextAttributes = [:]
        }

        static func dismantleUIView(_ uiView: UITextView, coordinator: Coordinator) {
            coordinator.cleanup(textView: uiView)
        }
        
        func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
            guard let width = proposal.width else { return nil }
            let key = SizeCache.Key(width: width, attributedHash: attributedText.hash)
            if let cached = Self.sizeCache.size(for: key) {
                return cached
            }
            let measured = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
            let size = CGSize(width: measured.width, height: measured.height)
            Self.sizeCache.insert(size, for: key)
            return size
        }

        final class Coordinator: NSObject, UITextViewDelegate {
            let openURL: OpenURLAction
            init(openURL: OpenURLAction) { self.openURL = openURL }

            func prepare(textView: UITextView) {
                textView.backgroundColor = .clear
                textView.isEditable = false
                textView.isScrollEnabled = false
                textView.isSelectable = true
                textView.textContainerInset = .zero
                textView.textContainer.lineFragmentPadding = 0
                textView.dataDetectorTypes = []
                textView.adjustsFontForContentSizeCategory = true
                textView.delegate = self
            }

            func cleanup(textView: UITextView) {
                textView.attributedText = nil
                textView.linkTextAttributes = [:]
                textView.delegate = nil
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
                let attributedHash: Int

                init(width: CGFloat, attributedHash: Int) {
                    self.widthBits = Double(width).bitPattern
                    self.attributedHash = attributedHash
                }
            }
        }
    }
}
