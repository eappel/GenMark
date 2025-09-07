import SwiftUI

struct MarkdownViewPreviews: PreviewProvider {
    static var previews: some View {
        Group {
            PreviewScreen(resource: "fixture_readme")
                .previewDisplayName("README Fixture")
            PreviewScreen(resource: "fixture_tables")
                .previewDisplayName("Tables Fixture")
            PreviewScreen(resource: "fixture_long")
                .previewDisplayName("Long Fixture")
        }
    }

    private struct PreviewScreen: View {
        let resource: String
        @State private var text: String = "Loading..."

        var body: some View {
            MarkdownView(text)
                .onAppear { load() }
        }

        private func load() {
            if let url = Bundle.module.url(
                forResource: resource,
                withExtension: "md"
            ) {
                if let s = try? String(contentsOf: url, encoding: .utf8) {
                    text = s
                    return
                }
            }
            text = "Failed to load fixture: \(resource)"
        }
    }
}
