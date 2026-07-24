import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            EditorsSettingsView()
                .tabItem {
                    Label("Editors", systemImage: "square.and.pencil")
                }

            ThemeSettingsView()
                .tabItem {
                    Label("Themes", systemImage: "paintpalette")
                }

            MarkdownSettingsView()
                .tabItem {
                    Label("Markdown", systemImage: "doc.plaintext")
                }

            PrintingSettingsView()
                .tabItem {
                    Label("Printing", systemImage: "printer")
                }
        }
        .frame(minWidth: 560, maxWidth: .infinity, minHeight: 350, maxHeight: .infinity)
    }
}

private struct SettingsScrollView<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView(.vertical) {
            content
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(20)
        }
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage("defaultTocVisible") private var defaultTocVisible = false
    @AppStorage("defaultTocDepth") private var defaultTocDepth = 3
    @AppStorage("defaultRawVisible") private var defaultRawVisible = false
    @AppStorage("tocWrap") private var tocWrap = false
    @AppStorage("tocBullets") private var tocBullets = false
    @State private var isDefault = false
    @State private var checkPerformed = false
    @State private var showCSSHelp = false

    var body: some View {
        SettingsScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("General")
                    .font(.headline)
                    .padding(.bottom, 16)

            GroupBox {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Default Markdown Viewer")
                            .font(.body)
                        if checkPerformed {
                            Text(isDefault
                                ? "markdownViewr is the default app for .md files."
                                : "Another app is currently set as the default for .md files.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if isDefault {
                        Label("Default", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.caption)
                    } else {
                        Button("Set as Default") {
                            setAsDefault()
                        }
                    }
                }
                .padding(4)
            }

            GroupBox {
                HStack {
                    Text("Frontmatter")
                        .font(.body)
                    Spacer()
                    Picker("", selection: $themeManager.frontmatterMode) {
                        ForEach(MarkdownDocument.FrontmatterMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 180)
                }
                .padding(4)
            }
            .padding(.top, 12)

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Max Content Width", isOn: $themeManager.contentWidthEnabled)
                        .toggleStyle(.checkbox)
                    if themeManager.contentWidthEnabled {
                        HStack(spacing: 10) {
                            Slider(value: $themeManager.contentWidthPx, in: 600...2400)
                                .onChange(of: themeManager.contentWidthPx) { v in
                                    themeManager.contentWidthPx = (v / 10).rounded() * 10
                                }
                            Text(String(format: "%d px", Int(themeManager.contentWidthPx)))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 52, alignment: .trailing)
                        }
                    }
                }
                .padding(4)
            }
            .padding(.top, 12)

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Show Table of Contents in new windows", isOn: $defaultTocVisible)
                        .toggleStyle(.checkbox)

                    HStack {
                        Text("Default Table of Contents depth")
                        Spacer()
                        Picker("Default Table of Contents depth", selection: $defaultTocDepth) {
                            ForEach(1...6, id: \.self) { depth in
                                Text("H\(depth)").tag(depth)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 90)
                    }

                    Toggle("Show Markdown Source in new windows", isOn: $defaultRawVisible)
                        .toggleStyle(.checkbox)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }
            .padding(.top, 12)

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Wrap long entries in the Table of Contents", isOn: $tocWrap)
                            .toggleStyle(.checkbox)
                        Text("When off, long headings are truncated with an ellipsis — hover an entry to see its full text.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Show depth markers in the Table of Contents", isOn: $tocBullets)
                            .toggleStyle(.checkbox)
                        Text("Marks each entry with a shape that varies by heading level (●, ○, ▪, –) to show depth.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }
            .padding(.top, 12)

            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Global Custom CSS")
                            .font(.body)
                        Button {
                            showCSSHelp.toggle()
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showCSSHelp, arrowEdge: .trailing) {
                            CSSHelpView()
                        }
                    }
                    Text("Applied to every document, regardless of theme.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $themeManager.globalCSS)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 100, maxHeight: 200)
                        .border(Color.secondary.opacity(0.3))
                        .scrollContentBackground(.hidden)
                }
                .padding(4)
            }
            .padding(.top, 12)

            Spacer()
            }
        }
        .onAppear {
            checkIfDefault()
        }
    }

    private static let markdownUTIs: [String] = {
        var utis: [String] = ["net.daringfireball.markdown"]
        if let resolved = UTType(filenameExtension: "md") {
            utis.append(resolved.identifier)
        }
        return Array(Set(utis))
    }()

    private func checkIfDefault() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }

        isDefault = Self.markdownUTIs.allSatisfy { uti in
            let handler = LSCopyDefaultRoleHandlerForContentType(
                uti as CFString,
                .all
            )?.takeRetainedValue() as String?
            return handler?.lowercased() == bundleID.lowercased()
        }
        checkPerformed = true
    }

    private func setAsDefault() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }

        for uti in Self.markdownUTIs {
            LSSetDefaultRoleHandlerForContentType(
                uti as CFString,
                .all,
                bundleID as CFString
            )
        }

        checkIfDefault()
    }
}

struct EditorsSettingsView: View {
    @EnvironmentObject var editorManager: EditorManager
    @State private var selectedEditorID: UUID?
    private let editorActionButtonSize: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("External Editors")
                .font(.headline)
                .padding(.bottom, 8)

            Text("Configure applications to open markdown files for editing.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 16)

            List(selection: $selectedEditorID) {
                ForEach(editorManager.editors) { editor in
                    HStack {
                        if let icon = NSWorkspace.shared.icon(forFile: editor.path) as NSImage? {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 24, height: 24)
                        }
                        VStack(alignment: .leading) {
                            HStack {
                                Text(editor.name)
                                if !editor.exists {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundStyle(.yellow)
                                        .help("Application not found at \(editor.path)")
                                }
                            }
                            Text(editor.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if editor.opensFolder {
                            Text("Opens folder")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quaternary)
                                .cornerRadius(4)
                        }
                    }
                    .tag(editor.id)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        editorManager.removeEditor(at: index)
                    }
                }
            }
            .listStyle(.bordered)
            .frame(minHeight: 150)

            HStack {
                Button {
                    addEditor()
                } label: {
                    Image(systemName: "plus")
                        .frame(width: editorActionButtonSize, height: editorActionButtonSize)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    if let id = selectedEditorID {
                        editorManager.removeEditor(id: id)
                        selectedEditorID = nil
                    }
                } label: {
                    Image(systemName: "minus")
                        .frame(width: editorActionButtonSize, height: editorActionButtonSize)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(selectedEditorID == nil)

                Divider()
                    .frame(height: editorActionButtonSize)
                    .padding(.horizontal, 2)

                Button {
                    moveSelectedEditor(by: -1)
                } label: {
                    Image(systemName: "chevron.up")
                        .frame(width: editorActionButtonSize, height: editorActionButtonSize)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Move selected editor up")
                .disabled(!canMoveSelectedEditorUp)

                Button {
                    moveSelectedEditor(by: 1)
                } label: {
                    Image(systemName: "chevron.down")
                        .frame(width: editorActionButtonSize, height: editorActionButtonSize)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Move selected editor down")
                .disabled(!canMoveSelectedEditorDown)

                Spacer()

                if let id = selectedEditorID,
                   let index = editorManager.editors.firstIndex(where: { $0.id == id }) {
                    Toggle("Opens folder instead of file", isOn: Binding(
                        get: { editorManager.editors[index].opensFolder },
                        set: { editorManager.setOpensFolder($0, for: id) }
                    ))
                    .font(.caption)
                }
            }
            .padding(.top, 8)
        }
        .padding(20)
    }

    private var selectedEditorIndex: Int? {
        guard let selectedEditorID else { return nil }
        return editorManager.editors.firstIndex { $0.id == selectedEditorID }
    }

    private var canMoveSelectedEditorUp: Bool {
        selectedEditorIndex.map { $0 > 0 } ?? false
    }

    private var canMoveSelectedEditorDown: Bool {
        selectedEditorIndex.map { $0 < editorManager.editors.count - 1 } ?? false
    }

    private func moveSelectedEditor(by offset: Int) {
        guard let selectedEditorID else { return }
        editorManager.moveEditor(id: selectedEditorID, by: offset)
    }

    private func addEditor() {
        let panel = NSOpenPanel()
        panel.title = "Select Application"
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let url = panel.url {
            let name = url.deletingPathExtension().lastPathComponent
            let editor = EditorConfig(name: name, path: url.path)
            editorManager.addEditor(editor)
        }
    }
}

struct MarkdownSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        SettingsScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Markdown Extensions")
                    .font(.headline)
                    .padding(.bottom, 8)

                Text("Enable or disable inline syntax extensions applied during rendering.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 16)

            GroupBox {
                VStack(spacing: 0) {
                    extensionRow(
                        name: "Highlight",
                        example: "==text==",
                        isOn: Binding(
                            get: { themeManager.markdownExtensions.highlight },
                            set: { themeManager.markdownExtensions.highlight = $0 }
                        )
                    )
                    Divider().padding(.vertical, 6)
                    extensionRow(
                        name: "Superscript",
                        example: "^text^",
                        isOn: Binding(
                            get: { themeManager.markdownExtensions.superscript },
                            set: { themeManager.markdownExtensions.superscript = $0 }
                        )
                    )
                    Divider().padding(.vertical, 6)
                    extensionRow(
                        name: "Subscript",
                        example: "~text~",
                        isOn: Binding(
                            get: { themeManager.markdownExtensions.subscript_ },
                            set: { themeManager.markdownExtensions.subscript_ = $0 }
                        )
                    )
                    Divider().padding(.vertical, 6)
                    extensionRow(
                        name: "Underline",
                        example: "++text++",
                        isOn: Binding(
                            get: { themeManager.markdownExtensions.underline },
                            set: { themeManager.markdownExtensions.underline = $0 }
                        )
                    )
                }
                .padding(4)
            }

            Spacer()
            }
        }
    }

    private func extensionRow(name: String, example: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(name)
                .frame(width: 100, alignment: .leading)
            Text(example)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.checkbox)
                .labelsHidden()
        }
        .padding(.vertical, 2)
    }
}

struct PrintingSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage("printTheme") private var printTheme = "Clean Printing"
    @AppStorage("printBackgrounds") private var printBackgrounds = false
    @AppStorage("printImages") private var printImages = true
    @AppStorage("printZoom") private var printZoom = "Standard (100%)"
    @AppStorage("printContentWidth") private var printContentWidth = "Full Page"
    @AppStorage("printBorders") private var printBorders = false
    @AppStorage("printPagePadding") private var printPagePadding = "0px"

    var body: some View {
        SettingsScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Printing")
                    .font(.headline)
                    .padding(.bottom, 16)

                GroupBox(label: Text("Print Theme")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Theme")
                            Spacer()
                            Picker("Print Theme", selection: $printTheme) {
                                Text("Active Screen Theme").tag("Active Theme")
                                Text("Plain HTML (Unstyled)").tag("Plain HTML")
                                Text("Clean Printing").tag("Clean Printing")
                                Divider()
                                ForEach(themeManager.themes, id: \.name) { theme in
                                    Text(theme.name).tag(theme.name)
                                }
                            }
                            .frame(width: 200)
                            .labelsHidden()
                        }

                        Text("Select the theme to use when printing or exporting to PDF.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(4)
                }

                GroupBox(label: Text("Page Layout")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Include Background Colors", isOn: $printBackgrounds)
                            .toggleStyle(.checkbox)

                        Text("When enabled, code block backgrounds, blockquotes, and highlights will print with their theme colors. Disable to save ink.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Divider().padding(.vertical, 4)

                        Toggle("Include Images", isOn: $printImages)
                            .toggleStyle(.checkbox)

                        Text("When enabled, inline and document images will print. Disable to save color ink and space.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Divider().padding(.vertical, 4)

                        Toggle("Include Content Borders", isOn: $printBorders)
                            .toggleStyle(.checkbox)

                        Text("When enabled, adds borders to styled blocks like code blocks, blockquotes, and tables to guarantee contrast with page background.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Divider().padding(.vertical, 4)

                        HStack {
                            Text("Page Padding")
                            Spacer()
                            Picker("Page Padding", selection: $printPagePadding) {
                                Text("None (0px)").tag("0px")
                                Text("Small (24px)").tag("24px")
                                Text("Medium (48px)").tag("48px")
                                Text("Large (72px)").tag("72px")
                            }
                            .frame(width: 200)
                            .labelsHidden()
                        }

                        Text("Add margins inside the background color container to keep text away from the page edge.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(4)
                }
                .padding(.top, 12)

                GroupBox(label: Text("Zoom & Scaling")) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Font Scaling")
                            Spacer()
                            Picker("Font Scaling", selection: $printZoom) {
                                Text("Compact (75%)").tag("Compact (75%)")
                                Text("Small (85%)").tag("Small (85%)")
                                Text("Standard (100%)").tag("Standard (100%)")
                                Text("Large (115%)").tag("Large (115%)")
                                Divider()
                                Text("Match Screen").tag("Match Screen")
                            }
                            .frame(width: 200)
                            .labelsHidden()
                        }

                        Text("Select the scale for printed document fonts, or match current screen zoom.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Divider().padding(.vertical, 4)

                        HStack {
                            Text("Content Width")
                            Spacer()
                            Picker("Content Width", selection: $printContentWidth) {
                                Text("Full Page Width").tag("Full Page")
                                Text("Match Screen Width").tag("Match Screen")
                            }
                            .frame(width: 200)
                            .labelsHidden()
                        }

                        Text("Select whether page layout uses full printable bounds or conforms to screen width guidelines.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(4)
                }
                .padding(.top, 12)
            }
        }
    }
}

struct ThemeEditorItem: Identifiable {
    let id = UUID()
    let theme: Theme?
}

struct ThemeSettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedThemeName: String?
    @State private var editorItem: ThemeEditorItem?
    @State private var showDeleteConfirm = false

    private var selectedTheme: Theme? {
        themeManager.allThemes.first { $0.name == selectedThemeName }
    }

    private var selectedThemeIndex: Int {
        themeManager.allThemes.firstIndex { $0.name == selectedThemeName } ?? -1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Themes")
                .font(.headline)
                .padding(.bottom, 8)

            HStack {
                Spacer()

                HStack(spacing: 0) {
                    Text("Enabled")
                        .frame(width: 56, alignment: .center)
                    Text("Default")
                        .frame(width: 56, alignment: .center)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.trailing, 20)
            }
            .padding(.bottom, 8)

            List(selection: $selectedThemeName) {
                ForEach(themeManager.allThemes) { theme in
                    let enabled = themeManager.isThemeEnabled(theme.name)
                    HStack(spacing: 0) {
                        HStack(spacing: 4) {
                            Circle().fill(Color(hex: theme.colors.background) ?? .gray)
                                .frame(width: 16, height: 16)
                                .overlay(Circle().stroke(.quaternary, lineWidth: 1))
                            Circle().fill(Color(hex: theme.colors.text) ?? .gray)
                                .frame(width: 16, height: 16)
                            Circle().fill(Color(hex: theme.colors.heading1) ?? .gray)
                                .frame(width: 16, height: 16)
                            Circle().fill(Color(hex: theme.colors.heading2) ?? .gray)
                                .frame(width: 16, height: 16)
                            Circle().fill(Color(hex: theme.colors.link) ?? .gray)
                                .frame(width: 16, height: 16)
                        }
                        .opacity(enabled ? 1.0 : 0.4)

                        Text(theme.name)
                            .padding(.leading, 8)
                            .foregroundStyle(enabled ? .primary : .secondary)

                        if theme.isBuiltIn {
                            Text("built-in")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .padding(.leading, 4)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { enabled },
                            set: { themeManager.setThemeEnabled(theme.name, enabled: $0) }
                        ))
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .frame(width: 56, alignment: .center)

                        Toggle("", isOn: Binding(
                            get: { theme.name == themeManager.activeThemeName },
                            set: { isOn in
                                if isOn {
                                    if !enabled {
                                        themeManager.setThemeEnabled(theme.name, enabled: true)
                                    }
                                    themeManager.activeThemeName = theme.name
                                }
                            }
                        ))
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                        .frame(width: 56, alignment: .center)
                    }
                    .tag(theme.name)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedThemeName = theme.name
                    }
                }
            }
            .listStyle(.bordered)

            HStack {
                Button("New") {
                    editorItem = ThemeEditorItem(theme: nil)
                }

                Button("Copy") {
                    guard let theme = selectedTheme else { return }
                    var copy = theme
                    copy.name = theme.name + " Copy"
                    copy.isBuiltIn = false
                    editorItem = ThemeEditorItem(theme: copy)
                }
                .disabled(selectedThemeName == nil)

                Button("Edit") {
                    guard let theme = selectedTheme else { return }
                    editorItem = ThemeEditorItem(theme: theme)
                }
                .disabled(selectedThemeName == nil)

                Button("Delete") {
                    showDeleteConfirm = true
                }
                .disabled(selectedThemeName == nil)

                Button {
                    if let name = selectedThemeName {
                        themeManager.moveThemeUp(name: name)
                    }
                } label: {
                    Image(systemName: "chevron.up")
                        .frame(minHeight: 16)
                }
                .disabled(selectedThemeName == nil || selectedThemeIndex == 0)

                Button {
                    if let name = selectedThemeName {
                        themeManager.moveThemeDown(name: name)
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .frame(minHeight: 16)
                }
                .disabled(selectedThemeName == nil || selectedThemeIndex == themeManager.allThemes.count - 1)

                Button("Import...") {
                    importThemes()
                }

                Button("Export...") {
                    if let theme = selectedTheme { exportTheme(theme) }
                }
                .disabled(selectedThemeName == nil)

                Spacer()

                Button("Restore Built-ins") {
                    themeManager.restoreBuiltInThemes()
                }
                .disabled(!themeManager.hasDeletedBuiltIns)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .onAppear {
            themeManager.loadThemes()
        }
        .onChange(of: editorItem?.id) { _ in
            if let item = editorItem {
                ThemeEditorWindowController.shared.show(
                    editingTheme: item.theme,
                    themeManager: themeManager
                )
                editorItem = nil
            }
        }
        .alert("Delete Theme?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                if let theme = selectedTheme {
                    try? themeManager.deleteTheme(theme)
                    selectedThemeName = nil
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let theme = selectedTheme {
                if theme.isBuiltIn {
                    Text("Remove \"\(theme.name)\" from the list? You can restore it later with \"Restore Built-ins\".")
                } else {
                    Text("Permanently delete \"\(theme.name)\"? This cannot be undone.")
                }
            }
        }
    }

    private func importThemes() {
        let panel = NSOpenPanel()
        panel.title = "Import Themes"
        panel.allowedContentTypes = [UTType.json]
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let data = try? Data(contentsOf: url),
                  let theme = try? JSONDecoder().decode(Theme.self, from: data)
            else { continue }
            if theme.schemaVersion > Theme.currentSchemaVersion {
                let alert = NSAlert()
                alert.messageText = "\"\(theme.name)\" was made with a newer version of markdownViewr"
                alert.informativeText = "It may not display correctly. Import anyway?"
                alert.addButton(withTitle: "Import")
                alert.addButton(withTitle: "Skip")
                if alert.runModal() != .alertFirstButtonReturn { continue }
            }

            let conflict = themeManager.allThemes.contains { $0.name == theme.name }
            if conflict {
                let alert = NSAlert()
                alert.messageText = "\"\(theme.name)\" already exists"
                alert.informativeText = "Choose how to handle the imported copy."
                alert.addButton(withTitle: "Overwrite")
                alert.addButton(withTitle: "Keep Both")
                alert.addButton(withTitle: "Skip")
                let resolution: ThemeManager.ImportConflictResolution
                switch alert.runModal() {
                case .alertFirstButtonReturn:  resolution = .overwrite
                case .alertSecondButtonReturn: resolution = .keepBoth
                default:                       resolution = .skip
                }
                themeManager.importTheme(theme, resolution: resolution)
            } else {
                themeManager.importTheme(theme)
            }
        }
    }

    private func exportTheme(_ theme: Theme) {
        let panel = NSSavePanel()
        panel.title = "Export Theme"
        panel.nameFieldStringValue = theme.name
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()
            .appending(".json")
        panel.allowedContentTypes = [UTType.json]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(theme) {
            try? data.write(to: url)
        }
    }
}

class ThemeEditorWindowController: NSObject, NSWindowDelegate {
    static let shared = ThemeEditorWindowController()
    private var window: NSWindow?

    func show(editingTheme: Theme?, themeManager: ThemeManager) {
        if let window, window.isVisible {
            window.close()
        }

        let editorView = ThemeEditorView(editingTheme: editingTheme)
            .environmentObject(themeManager)

        let hostingView = NSHostingView(rootView: editorView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 1000, height: 900)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 900),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = editingTheme == nil ? "New Theme" : "Edit Theme"
        window.contentView = hostingView
        window.minSize = NSSize(width: 800, height: 400)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)

        self.window = window
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
