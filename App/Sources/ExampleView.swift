import SwiftUI
import GenMarkUI

struct ExampleView: View {
    @State private var text: String = "# GenMark\n\nLoading fixture..."
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack {
                    MarkdownView(
                        text
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .listRowSpacing(0)
                    .listSectionSpacing(0)
                    .listRowSeparator(.hidden)
                    .listSectionSeparator(.hidden)
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
                }
                //            }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.defaultMinListRowHeight, 0)
                .environment(\.defaultMinListHeaderHeight, 0)
                .navigationTitle("GenMark Preview")
                .onAppear  { loadFixture("fixture_readme") }
                .toolbar {
                    Menu("Fixture") {
                        Button("README") { loadFixture("fixture_readme") }
                        Button("Parser Options") { loadFixture("fixture_parser_options") }
                        Button("Tables") { loadFixture("fixture_tables") }
                        Button("Long") { loadFixture("fixture_long") }
                        Button("Lists Test") { loadFixture("fixture_lists_test") }
                    }
                }
            }
        }
    }

    private func loadFixture(_ name: String) {
        if let url = Bundle.module.url(
            forResource: name,
            withExtension: "md"
        ),
           let s = try? String(contentsOf: url, encoding: .utf8) {
            text = s + s + s + s + s + s + s
            return
        }
        text = "Failed to load \(name).md"
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View { ExampleView() }
}
