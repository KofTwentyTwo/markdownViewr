import SwiftUI

class LiveContent: ObservableObject {
    @Published var rawMarkdown: String = ""
    var fileWatcher: FileWatcher?

    func startWatching(fileURL: URL) {
        fileWatcher = FileWatcher(url: fileURL) { [weak self, fileURL] in
            guard let self else { return }
            guard let data = try? Data(contentsOf: fileURL),
                  let text = String(data: data, encoding: .utf8)
            else { return }
            if text != self.rawMarkdown {
                self.rawMarkdown = text
            }
        }
    }
}

struct ContentView: View {
    @Binding var document: MarkdownDocument
    let fileURL: URL?

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var editorManager: EditorManager

    @State private var showMissingEditorAlert = false
    @State private var missingEditorName = ""
    @StateObject private var liveContent = LiveContent()
    @StateObject private var findBar = FindBarController()
    @State private var renderedHTML = ""
    @State private var tocVisible = false
    @State private var tocDepth = 3

    private var currentMarkdown: String {
        liveContent.rawMarkdown.isEmpty ? document.rawMarkdown : liveContent.rawMarkdown
    }

    private func rerender() {
        renderedHTML = MarkdownDocument.convertToHTML(
            currentMarkdown,
            frontmatterMode: themeManager.frontmatterMode,
            extensions: themeManager.markdownExtensions
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if findBar.isVisible {
                FindBarView(findBar: findBar)
            }
            MarkdownWebView(
                html: renderedHTML,
                themeCSS: themeManager.generateCSS(for: themeManager.activeTheme),
                fileURL: fileURL,
                findBar: findBar,
                tocVisible: tocVisible,
                tocDepth: tocDepth
            )
        }
        .onReceive(themeManager.$frontmatterMode) { _ in
            DispatchQueue.main.async { rerender() }
        }
        .onReceive(themeManager.$markdownExtensions) { _ in
            DispatchQueue.main.async { rerender() }
        }
        .onReceive(liveContent.$rawMarkdown) { _ in
            DispatchQueue.main.async { rerender() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .findToggle)) { _ in
            if NSApp.keyWindow == findBar.window { findBar.toggle() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .findNext)) { _ in
            if NSApp.keyWindow == findBar.window { findBar.findNext() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .findPrevious)) { _ in
            if NSApp.keyWindow == findBar.window { findBar.findPrevious() }
        }
        .background(WindowAccessor { window in
            findBar.window = window
        })
        .onAppear {
            liveContent.rawMarkdown = document.rawMarkdown
            rerender()
            if let fileURL {
                liveContent.startWatching(fileURL: fileURL)
            }
        }
        .onDisappear {
            liveContent.fileWatcher = nil
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                tocControls
                zoomControls
                palettePicker
                editorButton
            }
        }
        .alert("Editor Not Found", isPresented: $showMissingEditorAlert) {
            Button("Remove from List") {
                editorManager.editors.removeAll { $0.name == missingEditorName }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"\(missingEditorName)\" could not be found. It may have been moved or uninstalled.")
        }
    }

    private var tocControls: some View {
        HStack(spacing: 2) {
            Button {
                tocVisible.toggle()
            } label: {
                Image(systemName: tocVisible ? "list.bullet.circle.fill" : "list.bullet.circle")
            }
            .help(tocVisible ? "Hide Table of Contents" : "Show Table of Contents")

            Picker("", selection: $tocDepth) {
                Text("H1").tag(1)
                Text("H2").tag(2)
                Text("H3").tag(3)
                Text("H4").tag(4)
                Text("H5").tag(5)
                Text("H6").tag(6)
            }
            .frame(width: 60)
            .disabled(!tocVisible)
            .help("Table of Contents depth")
        }
    }

    private var zoomControls: some View {
        HStack(spacing: 2) {
            Button {
                themeManager.zoomOut()
            } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .help("Zoom Out")

            Text("\(Int(themeManager.zoomScale * 100))%")
                .font(.system(size: 11).monospacedDigit())
                .frame(width: 38)
                .onTapGesture {
                    themeManager.zoomReset()
                }
                .help("Reset Zoom")

            Button {
                themeManager.zoomIn()
            } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .help("Zoom In")
        }
    }

    private var palettePicker: some View {
        Picker(selection: $themeManager.activeThemeName) {
            ForEach(themeManager.themes) { theme in
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(hex: theme.colors.heading1) ?? .purple)
                        .frame(width: 10, height: 10)
                    Text(theme.name)
                }
                .tag(theme.name)
            }
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: themeManager.activeTheme.colors.heading1) ?? .purple)
                    .frame(width: 10, height: 10)
                Text(themeManager.activeTheme.name)
                    .font(.system(size: 12))
            }
        }
        .pickerStyle(.menu)
    }

    @ViewBuilder
    private var editorButton: some View {
        let validEditors = editorManager.editors.filter(\.exists)

        if editorManager.editors.isEmpty {
            Button {
            } label: {
                Label("Open in Editor", systemImage: "square.and.pencil")
            }
            .disabled(true)
            .help("Configure an external editor in Settings")
        } else if validEditors.count == 1 {
            Button {
                openInEditor(validEditors[0])
            } label: {
                Label("Open in \(validEditors[0].name)", systemImage: "square.and.pencil")
            }
            .help("Open in \(validEditors[0].name)")
        } else {
            Menu {
                ForEach(editorManager.editors) { editor in
                    Button {
                        openInEditor(editor)
                    } label: {
                        HStack {
                            Text(editor.name)
                            if editor.opensFolder {
                                Text("(folder)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            } label: {
                Label("Open in Editor", systemImage: "square.and.pencil")
            }
            .help("Open in external editor")
        }
    }

    private func openInEditor(_ editor: EditorConfig) {
        guard let fileURL else { return }

        guard editor.exists else {
            missingEditorName = editor.name
            showMissingEditorAlert = true
            return
        }

        editorManager.openFile(fileURL, with: editor)
    }
}

struct FindBarView: View {
    @ObservedObject var findBar: FindBarController

    var body: some View {
        HStack(spacing: 8) {
            FocusableTextField(
                text: $findBar.searchText,
                placeholder: "Find in document...",
                onSubmit: { findBar.findNext() },
                onEscape: { findBar.hide() }
            )
            .frame(maxWidth: 300)

            if let status = findBar.matchStatus, !findBar.searchText.isEmpty {
                Text(status.total == 0 ? "No matches" : "\(status.current) of \(status.total)")
                    .font(.caption)
                    .foregroundStyle(status.total == 0 ? .red : .secondary)
                    .monospacedDigit()
                    .frame(minWidth: 70)
            }

            Button {
                findBar.findPrevious()
            } label: {
                Image(systemName: "chevron.up")
                    .frame(minHeight: 16)
            }
            .disabled(findBar.searchText.isEmpty)

            Button {
                findBar.findNext()
            } label: {
                Image(systemName: "chevron.down")
                    .frame(minHeight: 16)
            }
            .disabled(findBar.searchText.isEmpty)

            Spacer()

            Button("Done") {
                findBar.hide()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }
}

struct FocusableTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void
    var onEscape: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = placeholder
        field.isBordered = true
        field.bezelStyle = .roundedBezel
        field.delegate = context.coordinator
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        DispatchQueue.main.async {
            field.window?.makeFirstResponder(field)
        }
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        if field.stringValue != text {
            field.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextFieldDelegate {
        let parent: FocusableTextField

        init(_ parent: FocusableTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onEscape()
                return true
            }
            return false
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    var onWindow: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            onWindow(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            onWindow(nsView.window)
        }
    }
}

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b)
    }
}
