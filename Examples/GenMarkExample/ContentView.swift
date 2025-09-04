import SwiftUI
import GenMark

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List(0..<5, id: \.self) { index in
                NavigationLink("Row \(index + 1)") {
                    SDKView()
                        .navigationTitle("Row \(index + 1)")
                }
            }
            .listStyle(.plain)
            .navigationTitle("GenMark Examples")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .ignoresSafeArea()
    }
}

