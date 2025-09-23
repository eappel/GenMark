import XCTest
import SwiftUI
@testable import GenMarkUI

/// Measures layout cost for the ExampleView-style List hosting a long markdown document.
/// Baseline: pre-optimization avg ≈0.062s (5 iterations); optimized avg ≈0.054s (#1.12x faster).
final class MarkdownViewLayoutPerformanceTests: XCTestCase {
    @MainActor
    func test_listLayoutPerformance_baseline() {
        let markdown = loadFixture("fixture_long")
        let repeated = Array(repeating: markdown, count: 7).joined(separator: "\n\n")

        let host = UIHostingController(rootView: ExampleListHarness(markdown: repeated))
        host.view.frame = CGRect(origin: .zero, size: CGSize(width: 390, height: 844))

        let window = UIWindow(frame: host.view.frame)
        window.rootViewController = host
        window.makeKeyAndVisible()

        // Initial run loop passes to mimic the view appearing on screen.
        runLoopSpin(seconds: 0.25)

        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        runLoopSpin(seconds: 0.1)

        let iterations = 5
        let total = measureTime {
            for _ in 0..<iterations {
                host.view.setNeedsLayout()
                host.view.layoutIfNeeded()
                runLoopSpin(seconds: 0.05)
            }
        }
        let average = total / Double(iterations)

        let baselineAverage: TimeInterval = 0.0619
        let ratio = average / baselineAverage
        let message = String(
            format: "Markdown list layout baseline avg=%.4fs (ratio=%.3fx vs 0.0619s)",
            average,
            ratio
        )
        NSLog("%@", message)
        print(message)
        fputs(message + "\n", stderr)
        XCTContext.runActivity(named: "Markdown list layout baseline") { activity in
            let attachment = XCTAttachment(string: message)
            attachment.lifetime = .keepAlways
            activity.add(attachment)
        }

        // Ensure we retain the measured improvement (≥5% faster than pre-optimization baseline of ~0.0619s).
        XCTAssertLessThan(
            average,
            baselineAverage * 0.95,
            "Layout average regressed: baseline 0.0619s, observed \(average)s"
        )
    }

    // MARK: - Helpers
    private func loadFixture(_ name: String, ext: String = "md") -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext) else {
            return "# Missing\n\nUnable to load fixture \(name).\(ext)"
        }
        return (try? String(contentsOf: url, encoding: .utf8)) ?? "# Failed\n\nUnable to read fixture contents."
    }

    @MainActor
    private func runLoopSpin(seconds: TimeInterval) {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: seconds))
    }

    private struct ExampleListHarness: View {
        let markdown: String

        var body: some View {
            List {
                MarkdownView(markdown)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .listRowSpacing(0)
                    .listSectionSpacing(0)
                    .listRowSeparator(.hidden)
                    .listSectionSeparator(.hidden)
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 0)
            .environment(\.defaultMinListHeaderHeight, 0)
        }
    }

    private func measureTime(_ block: () -> Void) -> TimeInterval {
        let start = CFAbsoluteTimeGetCurrent()
        block()
        return CFAbsoluteTimeGetCurrent() - start
    }
}
