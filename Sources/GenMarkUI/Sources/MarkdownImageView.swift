import SwiftUI
import UIKit

struct MarkdownImageView: View {
    @Environment(\.markdownImageLoader) private var loader

    let url: URL
    let altText: String?
    let sizeHint: CGSize?

    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var didFail = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .accessibilityHidden(true)
                    .frame(height: sizeHint?.height)
            } else if isLoading {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.1))
                    ProgressView()
                }
                .frame(maxWidth: .infinity)
                .frame(height: placeholderHeight)
            } else if didFail {
                failureView
            } else {
                placeholderView
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .task(id: url) { await load() }
        .accessibilityLabel(altText ?? url.lastPathComponent)
    }

    private var placeholderHeight: CGFloat {
        sizeHint?.height ?? 120
    }

    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            .overlay(
                Text(altText ?? url.lastPathComponent)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(12)
            )
            .frame(maxWidth: .infinity)
            .frame(height: placeholderHeight)
    }

    private var failureView: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(Color.red.opacity(0.4), lineWidth: 1)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .imageScale(.large)
                        .foregroundStyle(.red)
                    Text(altText ?? "Image failed to load")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(12)
            )
            .frame(maxWidth: .infinity)
            .frame(height: placeholderHeight)
    }

    @MainActor
    private func load() async {
        guard image == nil else { return }
        isLoading = true
        didFail = false

        await withCheckedContinuation { continuation in
            loader.load(url: url, sizeHint: sizeHint) { loadedImage in
                self.image = loadedImage
                self.isLoading = false
                self.didFail = loadedImage == nil
                continuation.resume()
            }
        }
    }
}
