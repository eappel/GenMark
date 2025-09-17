import SwiftUI
import GenMarkUI
import GenMarkCore

struct ParserOptionsExampleView: View {
    @State private var enableSmartTypography = false
    @State private var enableHardBreaks = false
    @State private var enableNoBreaks = false
    @State private var selectedExtensions = GFMExtension.standard
    
    private let sampleText = """
    # Parser Options Demo
    
    ## Typography
    "Smart quotes" and 'apostrophes' -- en dash --- em dash
    
    ## Line Breaks
    Line one
    Line two
    Line three
    
    ## Extensions
    ~~Strikethrough text~~
    https://auto-linked.com
    
    | Table | Demo |
    |-------|------|
    | Cell  | Text |
    
    - [ ] Task item
    """
    
    private var currentOptions: ParserOptions {
        var options: ParserOptions = [.default, .unsafe]
        if enableSmartTypography { options.insert(.smart) }
        if enableHardBreaks { options.insert(.hardBreaks) }
        if enableNoBreaks { options.insert(.noBreaks) }
        return options
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Options controls
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Parser Options")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Toggle("Smart Typography", isOn: $enableSmartTypography)
                            Toggle("Hard Breaks", isOn: $enableHardBreaks)
                                .disabled(enableNoBreaks)
                            Toggle("No Breaks", isOn: $enableNoBreaks)
                                .disabled(enableHardBreaks)
                        }
                        .padding(.horizontal)
                        
                        Text("Extensions")
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.top, 8)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(GFMExtension.allCases), id: \.self) { ext in
                                HStack {
                                    Image(systemName: selectedExtensions.contains(ext) ? "checkmark.square.fill" : "square")
                                        .foregroundColor(.accentColor)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(String(describing: ext))
                                            .font(.system(.body, design: .monospaced))
                                    }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if selectedExtensions.contains(ext) {
                                        selectedExtensions.remove(ext)
                                    } else {
                                        selectedExtensions.insert(ext)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
                .frame(height: 250)
                .background(Color(UIColor.secondarySystemBackground))
                
                Divider()
                
                // Markdown preview with current options
                MarkdownView(
                    sampleText,
                    parserOptions: currentOptions,
                    extensions: selectedExtensions
                )
                .padding()
                
                Spacer()
            }
            .navigationTitle("Parser Options")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ParserOptionsExampleView_Previews: PreviewProvider {
    static var previews: some View {
        ParserOptionsExampleView()
    }
}
