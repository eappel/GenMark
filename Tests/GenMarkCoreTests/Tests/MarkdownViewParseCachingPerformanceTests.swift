import XCTest
@testable import GenMarkUI

/**
 Performance: MarkdownView parse caching
 
 - Purpose: Measures repeated body reevaluation with and without the parsed-model cache to verify a measurable improvement.
 - How to run:
   - Console run: `make test-debug`
   - Save result bundle with attachments: `make test-bundle RESULT_BUNDLE=Derived/TestResults.xcresult`
 - How to inspect metrics:
   - Console/logs: search for the line beginning with `Parsing cache perf:`
   - Result bundle: open `Derived/TestResults.xcresult` in Xcode and view the attachment named "MarkdownView parsing cache metrics"; or extract via:
     `xcrun xcresulttool get --format json --path Derived/TestResults.xcresult > result.json` and search for `Parsing cache perf`.
 - Baseline (local sim, iPhone 16 iOS 18.6, 50 iterations):
   - uncached ~0.0326s
   - cached ~0.000090s
   - ratio ~0.003x (≈362x faster)
 - Assertion: requires a conservative ≥2x improvement to remain robust across environments.
 */
final class MarkdownViewParseCachingPerformanceTests: XCTestCase {
    private func loadFixture(_ name: String, ext: String = "md") -> String {
        let url = Bundle.module.url(forResource: name, withExtension: ext)!
        return (try? String(contentsOf: url, encoding: .utf8)) ?? "# Fallback\n\nThis is a fallback fixture."
    }

    @MainActor
    func test_bodyReevaluation_cached_vs_uncached_performance() {
        // Load a reasonably large markdown to amplify parsing cost
        let md = loadFixture("fixture_long")

        // Warm up: ensure any one-time costs are paid before measurements
        _ = MarkdownView(md).body
        _ = MarkdownView(md, disableParsingCacheForTesting: true).body

        // Measure repeated body evaluation WITHOUT cache
        let iterations = 50
        let uncachedDuration: TimeInterval = measureTime {
            let view = MarkdownView(md, disableParsingCacheForTesting: true)
            for _ in 0..<iterations { _ = view.body }
        }

        // Measure repeated body evaluation WITH cache
        // Parse once outside timing to simulate steady-state re-renders
        let cachedView = MarkdownView(md)
        _ = cachedView.body // initial parse happens here (constructor also pre-parses)
        let cachedDuration: TimeInterval = measureTime {
            for _ in 0..<iterations { _ = cachedView.body }
        }

        // Assert a meaningful improvement. The exact ratio depends on environment,
        // but cached should be significantly faster because it avoids repeated parsing.
        // Target at least 2x faster; adjust if CI hardware variance requires.
        XCTAssertLessThan(cachedDuration, uncachedDuration * 0.5,
                          "Cached body evaluation should be at least 2x faster than uncached.\nuncached=\(uncachedDuration)s, cached=\(cachedDuration)s")

        // Log the measured numbers so we can record baselines in comments/README
        let ratio = uncachedDuration > 0 ? (cachedDuration / uncachedDuration) : 0
        let message = String(
            format: "Parsing cache perf: uncached=%.6fs, cached=%.6fs, ratio=%.3fx",
            uncachedDuration, cachedDuration, ratio
        )
        // Emit via multiple channels to improve visibility in logs
        NSLog("%@", message)
        fputs(message + "\n", stderr)
        XCTContext.runActivity(named: "MarkdownView parsing cache metrics") { activity in
            let att = XCTAttachment(string: message)
            att.lifetime = .keepAlways
            activity.add(att)
        }

        // Baseline (local sim, iPhone 16 iOS 18.6, 50 iterations):
        // uncached ~0.0326s, cached ~0.000090s (~362x faster)
        // Keep assertion at 2x to remain robust across environments.
    }

    // MARK: - Helpers
    private func measureTime(_ block: () -> Void) -> TimeInterval {
        let start = CFAbsoluteTimeGetCurrent()
        block()
        return CFAbsoluteTimeGetCurrent() - start
    }
}
