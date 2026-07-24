import SwiftUI
import WebKit

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
    @StateObject private var folderAccess = FolderAccessManager()
    @State private var renderedHTML = ""
    @State private var docNeedsImageAccess = false
    @StateObject private var toolbarController = DocumentToolbarController()
    @AppStorage("defaultTocVisible") private var defaultTocVisible = false
    @AppStorage("defaultTocDepth") private var defaultTocDepth = 3
    @AppStorage("defaultRawVisible") private var defaultRawVisible = false
    @State private var tocVisible = false
    @State private var tocDepth = 3
    @State private var tocWidth: Double = 220
    @AppStorage("tocWrap") private var tocWrap = false
    @AppStorage("tocBullets") private var tocBullets = false
    @State private var rawVisible = false
    @State private var rawWidth: Double = 400
    @State private var hasActivatedRawSource = false
    @State private var hasInitializedWindowViewState = false
    @State private var zoomScale = 1.0
    @State private var activeThemeName: String?
    @AppStorage("printTheme") private var printTheme = "Clean Printing"
    @AppStorage("printBackgrounds") private var printBackgrounds = false
    @AppStorage("printImages") private var printImages = true
    @AppStorage("printZoom") private var printZoom = "Standard (100%)"
    @AppStorage("printContentWidth") private var printContentWidth = "Full Page"
    @AppStorage("printBorders") private var printBorders = false
    @AppStorage("printPagePadding") private var printPagePadding = "0px"

    private var currentMarkdown: String {
        liveContent.rawMarkdown.isEmpty ? document.rawMarkdown : liveContent.rawMarkdown
    }

    private var activeTheme: Theme {
        let themeName = activeThemeName ?? themeManager.activeThemeName
        return themeManager.themes.first { $0.name == themeName } ?? themeManager.activeTheme
    }

    private func rerender() {
        let html = MarkdownDocument.convertToHTML(
            currentMarkdown,
            frontmatterMode: themeManager.frontmatterMode,
            extensions: themeManager.markdownExtensions
        )
        #if MAS_BUILD
        if folderAccess.hasAccess {
            renderedHTML = ImageInliner.inlineLocalImages(in: html) { path in
                folderAccess.imageData(forRelativePath: path)
            }
            docNeedsImageAccess = false
        } else {
            renderedHTML = html
            // Only prompt for folder access when the document actually has local images.
            docNeedsImageAccess = ImageInliner.containsLocalImage(in: html)
        }
        #else
        renderedHTML = html
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            if findBar.isVisible {
                FindBarView(findBar: findBar)
            }
            if docNeedsImageAccess {
                FolderAccessBanner {
                    folderAccess.requestAccess { granted in
                        if granted { rerender() }
                    }
                }
            }
            MarkdownWebView(
                html: renderedHTML,
                themeCSS: themeManager.generateCSS(for: activeTheme, zoomScale: zoomScale),
                fileURL: fileURL,
                findBar: findBar,
                tocVisible: tocVisible,
                tocDepth: tocDepth,
                tocWidth: tocWidth,
                tocWrap: tocWrap,
                tocBullets: tocBullets,
                rawSource: currentMarkdown,
                rawVisible: rawVisible,
                rawWidth: rawWidth,
                onTocWidthChange: { tocWidth = $0 },
                onRawWidthChange: { rawWidth = $0 }
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
            if let window {
                initializeWindowViewStateIfNeeded(windowWidth: Double(window.contentView?.bounds.width ?? 0))
                toolbarController.configure(
                    in: window,
                    themeManager: themeManager,
                    editorManager: editorManager,
                    fileURL: fileURL,
                    tocVisible: tocVisible,
                    tocDepth: tocDepth,
                    rawVisible: rawVisible,
                    zoomScale: zoomScale,
                    activeThemeName: activeTheme.name,
                    setTocVisible: { tocVisible = $0 },
                    setTocDepth: { tocDepth = $0 },
                    setRawVisible: setRawSourceVisible,
                    setZoomScale: { zoomScale = $0 },
                    setActiveThemeName: { activeThemeName = $0 },
                    printDocument: { printActiveDocument() },
                    showMissingEditor: { editorName in
                        missingEditorName = editorName
                        showMissingEditorAlert = true
                    }
                )
            }
        })
        .onAppear {
            liveContent.rawMarkdown = document.rawMarkdown
            if let fileURL {
                // Watching the opened document does not require the folder grant —
                // the document itself is accessible via the document architecture.
                folderAccess.prepare(for: fileURL)
                liveContent.startWatching(fileURL: fileURL)
            }
            rerender()
        }
        .onDisappear {
            liveContent.fileWatcher = nil
        }
        .alert("Editor Not Found", isPresented: $showMissingEditorAlert) {
            Button("Remove from List") {
                editorManager.editors.removeAll { $0.name == missingEditorName }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\"\(missingEditorName)\" could not be found. It may have been moved or uninstalled.")
        }
        .focusedSceneValue(\.documentViewCommands, documentViewCommands)
    }

    private var documentViewCommands: DocumentViewCommands {
        DocumentViewCommands(
            tocVisible: Binding(
                get: { tocVisible },
                set: { tocVisible = $0 }
            ),
            tocDepth: tocDepth,
            setTocDepth: { tocDepth = $0 },
            rawVisible: Binding(
                get: { rawVisible },
                set: setRawSourceVisible
            ),
            zoomScale: Binding(
                get: { zoomScale },
                set: { zoomScale = $0 }
            ),
            zoomIn: { zoomScale = min(zoomScale * 1.1, 5.0) },
            zoomOut: { zoomScale = max(zoomScale / 1.1, 0.3) },
            zoomReset: { zoomScale = 1.0 },
            nextTheme: { cycleTheme(direction: 1) },
            previousTheme: { cycleTheme(direction: -1) },
            printDocument: { printActiveDocument() }
        )
    }

    private func cycleTheme(direction: Int) {
        guard !themeManager.themes.isEmpty else { return }
        let currentThemeName = activeThemeName ?? themeManager.activeThemeName
        let currentIndex = themeManager.themes.firstIndex { $0.name == currentThemeName } ?? 0
        let newIndex = (currentIndex + direction + themeManager.themes.count) % themeManager.themes.count
        activeThemeName = themeManager.themes[newIndex].name
    }

    private func setRawSourceVisible(_ visible: Bool) {
        if visible && !rawVisible {
            rawWidth = DocumentViewLayout.rawWidthWhenActivating(
                currentRawWidth: rawWidth,
                hasActivatedRawSource: hasActivatedRawSource,
                windowWidth: Double(findBar.window?.contentView?.bounds.width ?? 0),
                tocVisible: tocVisible,
                tocWidth: tocWidth
            )
            hasActivatedRawSource = true
        }
        rawVisible = visible
    }

    private func initializeWindowViewStateIfNeeded(windowWidth: Double) {
        if hasInitializedWindowViewState {
            sizeInitialRawSourceIfNeeded(windowWidth: windowWidth)
            return
        }
        hasInitializedWindowViewState = true
        activeThemeName = themeManager.activeThemeName
        tocVisible = defaultTocVisible
        tocDepth = defaultTocDepth
        rawVisible = defaultRawVisible
        sizeInitialRawSourceIfNeeded(windowWidth: windowWidth)
    }

    private func sizeInitialRawSourceIfNeeded(windowWidth: Double) {
        guard rawVisible && !hasActivatedRawSource && windowWidth > 0 else { return }
        rawWidth = DocumentViewLayout.rawWidthWhenActivating(
            currentRawWidth: rawWidth,
            hasActivatedRawSource: hasActivatedRawSource,
            windowWidth: windowWidth,
            tocVisible: tocVisible,
            tocWidth: tocWidth
        )
        hasActivatedRawSource = true
    }

    /// Triggers the native macOS print sheet modal for the active Markdown document.
    /// It temporarily swaps in the print-specific theme CSS, applies layout class overrides,
    /// presents the print panel, and restores the original theme when the print flow concludes.
    @MainActor
    private func printActiveDocument() {
        guard let window = findBar.window else { return }
        guard let webView = window.contentView?.firstSubview(ofType: WKWebView.self) else { return }

        let themeToPrint: Theme?
        if printTheme == "Active Theme" {
            themeToPrint = activeTheme
        } else if printTheme == "Clean Printing" {
            themeToPrint = Theme.cleanPrinting
        } else if printTheme == "Plain HTML" {
            themeToPrint = nil
        } else {
            themeToPrint = themeManager.allThemes.first { $0.name == printTheme }
                ?? themeManager.themes.first { $0.name == printTheme }
                ?? Theme.cleanPrinting
        }

        // Determine zoom scale based on print settings
        let zoom = PrintZoomResolver.zoomScale(for: printZoom, screenZoom: zoomScale)

        let printCSS = themeToPrint != nil ? themeManager.generateCSS(for: themeToPrint!, zoomScale: zoom) : ""
        let escapedPrintCSS = printCSS.escapedForJavaScriptLiteral()
        let prepareJS = PrintScriptGenerator.prepareScript(
            escapedCSS: escapedPrintCSS,
            stripBackgrounds: !printBackgrounds,
            stripImages: !printImages,
            stripWidth: printContentWidth == "Full Page",
            printBorders: printBorders,
            pagePadding: printPagePadding
        )

        let restoreCSS = themeManager.generateCSS(for: activeTheme, zoomScale: zoomScale)
        let printBackgroundsVal = printBackgrounds
        let printImagesVal = printImages
        let printContentWidthVal = printContentWidth
        let printBordersVal = printBorders
        let printPagePaddingVal = printPagePadding

        webView.evaluateJavaScript(prepareJS) { [weak webView] _, _ in
            guard let webView = webView else { return }

            guard let printInfo = NSPrintInfo.shared.copy() as? NSPrintInfo else { return }
            printInfo.horizontalPagination = .fit
            printInfo.verticalPagination = .automatic
            printInfo.leftMargin = 36
            printInfo.rightMargin = 36
            printInfo.topMargin = 36
            printInfo.bottomMargin = 36

            let printOp = webView.printOperation(with: printInfo)
            printOp.showsPrintPanel = true
            printOp.showsProgressPanel = true

            let coordinator = PrintCoordinator(
                webView: webView,
                restoreCSS: restoreCSS,
                stripBackgrounds: !printBackgroundsVal,
                stripImages: !printImagesVal,
                stripWidth: printContentWidthVal == "Full Page",
                printBorders: printBordersVal,
                pagePadding: printPagePaddingVal
            )
            let coordinatorPointer = Unmanaged.passRetained(coordinator).toOpaque()

            printOp.runModal(
                for: window,
                delegate: coordinator,
                didRun: #selector(PrintCoordinator.printOperationDidRun(_:success:contextInfo:)),
                contextInfo: coordinatorPointer
            )
        }
    }

}

enum DocumentViewLayout {
    static func initialRawWidth(windowWidth: Double, tocVisible: Bool, tocWidth: Double) -> Double {
        let availableWidth = max(0, windowWidth - (tocVisible ? tocWidth : 0))
        return max(220, availableWidth / 2)
    }

    static func rawWidthWhenActivating(
        currentRawWidth: Double,
        hasActivatedRawSource: Bool,
        windowWidth: Double,
        tocVisible: Bool,
        tocWidth: Double
    ) -> Double {
        if hasActivatedRawSource {
            return currentRawWidth
        }
        return initialRawWidth(windowWidth: windowWidth, tocVisible: tocVisible, tocWidth: tocWidth)
    }
}

struct DocumentViewCommands {
    let tocVisible: Binding<Bool>
    let tocDepth: Int
    let setTocDepth: (Int) -> Void
    let rawVisible: Binding<Bool>
    let zoomScale: Binding<Double>
    let zoomIn: () -> Void
    let zoomOut: () -> Void
    let zoomReset: () -> Void
    let nextTheme: () -> Void
    let previousTheme: () -> Void
    let printDocument: () -> Void
}

private struct DocumentViewCommandsKey: FocusedValueKey {
    typealias Value = DocumentViewCommands
}

extension FocusedValues {
    var documentViewCommands: DocumentViewCommands? {
        get { self[DocumentViewCommandsKey.self] }
        set { self[DocumentViewCommandsKey.self] = newValue }
    }
}

final class DocumentToolbarController: NSObject, ObservableObject, NSToolbarDelegate {
    private weak var themeManager: ThemeManager?
    private weak var editorManager: EditorManager?
    private weak var window: NSWindow?
    private var fileURL: URL?
    private var tocVisible = false
    private var tocDepth = 3
    private var rawVisible = false
    private var zoomScale = 1.0
    private var activeThemeName = ""
    private var setTocVisible: ((Bool) -> Void)?
    private var setTocDepth: ((Int) -> Void)?
    private var setRawVisible: ((Bool) -> Void)?
    private var setZoomScale: ((Double) -> Void)?
    private var setActiveThemeName: ((String) -> Void)?
    private var printDocument: (() -> Void)?
    private var showMissingEditor: ((String) -> Void)?

    func configure(
        in window: NSWindow,
        themeManager: ThemeManager,
        editorManager: EditorManager,
        fileURL: URL?,
        tocVisible: Bool,
        tocDepth: Int,
        rawVisible: Bool,
        zoomScale: Double,
        activeThemeName: String,
        setTocVisible: @escaping (Bool) -> Void,
        setTocDepth: @escaping (Int) -> Void,
        setRawVisible: @escaping (Bool) -> Void,
        setZoomScale: @escaping (Double) -> Void,
        setActiveThemeName: @escaping (String) -> Void,
        printDocument: @escaping () -> Void,
        showMissingEditor: @escaping (String) -> Void
    ) {
        self.window = window
        self.themeManager = themeManager
        self.editorManager = editorManager
        self.fileURL = fileURL
        self.tocVisible = tocVisible
        self.tocDepth = tocDepth
        self.rawVisible = rawVisible
        self.zoomScale = zoomScale
        self.activeThemeName = activeThemeName
        self.setTocVisible = setTocVisible
        self.setTocDepth = setTocDepth
        self.setRawVisible = setRawVisible
        self.setZoomScale = setZoomScale
        self.setActiveThemeName = setActiveThemeName
        self.printDocument = printDocument
        self.showMissingEditor = showMissingEditor

        Self.removeLegacySavedToolbarConfigurations()
        if window.toolbar?.identifier != .documentToolbar {
            let toolbar = NSToolbar(identifier: .documentToolbar)
            toolbar.delegate = self
            toolbar.allowsUserCustomization = true
            toolbar.autosavesConfiguration = true
            toolbar.displayMode = NSToolbar.DisplayMode.default
            window.toolbar = toolbar
        } else if window.toolbar?.delegate !== self {
            window.toolbar?.delegate = self
        }

        updateVisibleItems()
    }

    private static func removeLegacySavedToolbarConfigurations() {
        let defaults = UserDefaults.standard
        for identifier in legacyToolbarIdentifiers {
            defaults.removeObject(forKey: "NSToolbar Configuration \(identifier)")
        }
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.toc, .tocDepth, .markdownSource, .zoom, .theme, .externalEditor, .printDocument, .space]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.toc, .tocDepth, .space, .markdownSource, .zoom, .theme, .externalEditor]
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        []
    }

    func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
        if item.itemIdentifier == .externalEditor {
            return hasValidExternalEditor
        }
        return true
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        switch itemIdentifier {
        case .toc:
            return makeTOCItem()
        case .tocDepth:
            return makeTOCDepthItem()
        case .markdownSource:
            return makeMarkdownSourceItem()
        case .zoom:
            return makeZoomItem()
        case .theme:
            return makeThemeItem()
        case .externalEditor:
            return makeExternalEditorItem()
        case .printDocument:
            return makePrintItem()
        default:
            return nil
        }
    }

    private func makeTOCItem() -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: .toc)
        item.label = "TOC"
        item.paletteLabel = "TOC"
        item.toolTip = tocVisible ? "Hide Table of Contents" : "Show Table of Contents"
        item.image = NSImage(systemSymbolName: tocVisible ? "list.bullet.circle.fill" : "list.bullet.circle", accessibilityDescription: "TOC")
        item.target = self
        item.action = #selector(toggleTOC)
        item.menuFormRepresentation = toolbarMenuItem(title: "TOC", action: #selector(toggleTOC), state: tocVisible ? .on : .off)
        return item
    }

    private func makeTOCDepthItem() -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: .tocDepth)
        item.label = "TOC Depth"
        item.paletteLabel = "TOC Depth"
        item.toolTip = "Table of Contents depth"
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 62, height: 26), pullsDown: false)
        for depth in 1...6 {
            popup.addItem(withTitle: "H\(depth)")
        }
        popup.selectItem(at: max(0, min(5, tocDepth - 1)))
        popup.isEnabled = tocVisible
        popup.target = self
        popup.action = #selector(tocDepthChanged(_:))
        item.view = popup
        item.menuFormRepresentation = tocDepthMenuItem()
        return item
    }

    private func makeMarkdownSourceItem() -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: .markdownSource)
        item.label = "Markdown Source"
        item.paletteLabel = "Markdown Source"
        item.toolTip = rawVisible ? "Hide Markdown Source" : "Show Markdown Source"
        item.image = NSImage(systemSymbolName: rawVisible ? "doc.plaintext.fill" : "doc.plaintext", accessibilityDescription: "Markdown Source")
        item.target = self
        item.action = #selector(toggleMarkdownSource)
        item.menuFormRepresentation = toolbarMenuItem(title: "Markdown Source", action: #selector(toggleMarkdownSource), state: rawVisible ? .on : .off)
        return item
    }

    private func makeZoomItem() -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: .zoom)
        item.label = "Zoom"
        item.paletteLabel = "Zoom"
        item.toolTip = "Zoom"
        item.view = zoomControlView()
        item.target = self
        item.action = #selector(showZoomMenuFromToolbar(_:))
        item.menuFormRepresentation = zoomMenuItem()
        return item
    }

    private func makeThemeItem() -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: .theme)
        item.label = "Theme"
        item.paletteLabel = "Theme"
        item.toolTip = "Theme"
        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 150, height: 26), pullsDown: false)
        for theme in themeManager?.themes ?? [] {
            popup.addItem(withTitle: theme.name)
        }
        popup.selectItem(withTitle: activeThemeName)
        popup.target = self
        popup.action = #selector(themeChanged(_:))
        item.view = popup
        item.menuFormRepresentation = themeMenuItem()
        return item
    }

    private func makeExternalEditorItem() -> NSToolbarItem {
        let editors = editorManager?.editors ?? []
        let validEditors = editors.filter(\.exists)
        let item = NSToolbarItem(itemIdentifier: .externalEditor)
        item.label = externalEditorLabel
        item.paletteLabel = "Open in Editor"
        item.toolTip = externalEditorHelp
        item.image = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "Open in Editor")
        item.target = self
        item.action = #selector(openExternalEditorFromToolbar(_:))
        item.autovalidates = false

        item.isEnabled = !validEditors.isEmpty
        item.view = externalEditorButton(isEnabled: !validEditors.isEmpty)

        if editors.isEmpty || validEditors.isEmpty {
            item.isEnabled = false
            item.menuFormRepresentation = toolbarMenuItem(title: externalEditorLabel, action: nil, isEnabled: false)
        } else if validEditors.count == 1 {
            item.menuFormRepresentation = toolbarMenuItem(title: externalEditorLabel, action: #selector(openExternalEditorFromToolbar(_:)))
        } else {
            item.menuFormRepresentation = toolbarMenuItem(title: externalEditorLabel, action: #selector(openExternalEditorFromToolbar(_:)))
        }
        return item
    }

    private func makePrintItem() -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: .printDocument)
        item.label = "Print"
        item.paletteLabel = "Print"
        item.toolTip = "Print"
        item.image = NSImage(systemSymbolName: "printer", accessibilityDescription: "Print")
        item.target = self
        item.action = #selector(printDocumentFromToolbar)
        item.menuFormRepresentation = toolbarMenuItem(title: "Print", action: #selector(printDocumentFromToolbar))
        return item
    }

    private var externalEditorLabel: String {
        let validEditors = editorManager?.editors.filter(\.exists) ?? []
        if validEditors.count == 1 {
            return "Open in \(validEditors[0].name)"
        }
        return "Open in Editor"
    }

    private var hasValidExternalEditor: Bool {
        editorManager?.editors.contains(where: \.exists) == true
    }

    private var externalEditorHelp: String {
        if editorManager?.editors.isEmpty == true {
            return "Configure an external editor in Settings"
        }
        return "Open in external editor"
    }

    private func externalEditorButton(isEnabled: Bool) -> NSButton {
        let button = NSButton(
            image: NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: "Open in Editor") ?? NSImage(),
            target: self,
            action: #selector(openExternalEditorFromToolbar(_:))
        )
        button.bezelStyle = .texturedRounded
        button.imagePosition = .imageOnly
        button.showsBorderOnlyWhileMouseInside = true
        button.isEnabled = isEnabled
        button.toolTip = externalEditorHelp
        button.setAccessibilityLabel(externalEditorLabel)
        button.frame = NSRect(x: 0, y: 0, width: 28, height: 28)
        return button
    }

    private func zoomControlView() -> NSView {
        ZoomToolbarControlView(control: zoomSegmentedControl())
    }

    private func zoomSegmentedControl() -> NSSegmentedControl {
        let control = NSSegmentedControl(labels: ["", "\(zoomPercent)%", ""], trackingMode: .momentary, target: self, action: #selector(zoomSegmentSelected(_:)))
        control.segmentStyle = .texturedRounded
        control.setImage(NSImage(systemSymbolName: "minus.magnifyingglass", accessibilityDescription: "Zoom Out"), forSegment: 0)
        control.setImage(NSImage(systemSymbolName: "plus.magnifyingglass", accessibilityDescription: "Zoom In"), forSegment: 2)
        control.setToolTip("Zoom Out", forSegment: 0)
        control.setToolTip("Actual Size", forSegment: 1)
        control.setToolTip("Zoom In", forSegment: 2)
        control.setWidth(28, forSegment: 0)
        control.setWidth(56, forSegment: 1)
        control.setWidth(28, forSegment: 2)
        control.setAccessibilityLabel("Zoom")
        return control
    }

    private var zoomPercent: Int {
        Int(round(zoomScale * 100))
    }

    private func zoomMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Zoom", action: nil, keyEquivalent: "")
        item.submenu = zoomMenu()
        return item
    }

    private func zoomMenu() -> NSMenu {
        let menu = NSMenu(title: "Zoom")
        menu.addItem(NSMenuItem(title: "Zoom Out", action: #selector(zoomOut), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Actual Size", action: #selector(actualSize), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Zoom In", action: #selector(zoomIn), keyEquivalent: ""))
        for menuItem in menu.items {
            menuItem.target = self
        }
        return menu
    }

    private func tocDepthMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "TOC Depth", action: nil, keyEquivalent: "")
        let menu = NSMenu(title: "TOC Depth")
        for depth in 1...6 {
            let menuItem = NSMenuItem(title: "H\(depth)", action: #selector(setTOCDepthFromMenu(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.tag = depth
            menuItem.state = tocDepth == depth ? .on : .off
            menu.addItem(menuItem)
        }
        item.submenu = menu
        return item
    }

    private func themeMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        let menu = NSMenu(title: "Theme")
        for theme in themeManager?.themes ?? [] {
            let menuItem = NSMenuItem(title: theme.name, action: #selector(themeChangedFromMenu(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.state = theme.name == activeThemeName ? .on : .off
            menu.addItem(menuItem)
        }
        item.submenu = menu
        return item
    }

    private func externalEditorMenu() -> NSMenu {
        let menu = NSMenu(title: "Open in Editor")
        for editor in editorManager?.editors ?? [] {
            let menuItem = NSMenuItem(title: editor.opensFolder ? "\(editor.name) (folder)" : editor.name, action: #selector(openExternalEditorFromMenu(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = editor.id
            menuItem.isEnabled = editor.exists
            menu.addItem(menuItem)
        }
        return menu
    }

    private func toolbarMenuItem(title: String, action: Selector?, state: NSControl.StateValue = .off, isEnabled: Bool = true) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.state = state
        item.isEnabled = isEnabled
        return item
    }

    @objc private func showZoomMenuFromToolbar(_ sender: Any?) {
        let menu = zoomMenu()
        if let view = sender as? NSView {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.height), in: view)
            return
        }

        guard let event = NSApp.currentEvent,
              let contentView = event.window?.contentView
        else { return }
        let point = contentView.convert(event.locationInWindow, from: nil)
        menu.popUp(positioning: nil, at: point, in: contentView)
    }

    @objc private func toggleTOC() {
        setTocVisible?(!tocVisible)
    }

    @objc private func tocDepthChanged(_ sender: NSPopUpButton) {
        setTocDepth?(sender.indexOfSelectedItem + 1)
    }

    @objc private func setTOCDepthFromMenu(_ sender: NSMenuItem) {
        setTocDepth?(sender.tag)
    }

    @objc private func toggleMarkdownSource() {
        setRawVisible?(!rawVisible)
    }

    @objc private func themeChanged(_ sender: NSPopUpButton) {
        guard let title = sender.selectedItem?.title else { return }
        setActiveThemeName?(title)
    }

    @objc private func themeChangedFromMenu(_ sender: NSMenuItem) {
        setActiveThemeName?(sender.title)
    }

    @objc private func openExternalEditorFromToolbar(_ sender: Any?) {
        let validEditors = editorManager?.editors.filter(\.exists) ?? []
        if validEditors.count == 1 {
            open(validEditors[0])
        } else if validEditors.count > 1 {
            showExternalEditorMenu(from: sender)
        }
    }

    @objc private func openExternalEditorFromMenu(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let editor = editorManager?.editors.first(where: { $0.id == id })
        else { return }
        open(editor)
    }

    private func open(_ editor: EditorConfig) {
        guard let fileURL else { return }
        guard editor.exists else {
            showMissingEditor?(editor.name)
            return
        }
        editorManager?.openFile(fileURL, with: editor)
    }

    private func showExternalEditorMenu(from sender: Any?) {
        let menu = externalEditorMenu()
        if let view = sender as? NSView {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: view.bounds.height), in: view)
            return
        }

        guard let contentView = window?.contentView else { return }
        let point: NSPoint
        if let event = NSApp.currentEvent, event.window === window {
            point = contentView.convert(event.locationInWindow, from: nil)
        } else if let window {
            point = contentView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        } else {
            point = NSPoint(x: contentView.bounds.midX, y: contentView.bounds.maxY)
        }
        menu.popUp(positioning: nil, at: point, in: contentView)
    }

    @objc private func zoomSegmentSelected(_ sender: NSSegmentedControl) {
        switch sender.selectedSegment {
        case 0:
            setZoomScale?(max(zoomScale / 1.1, 0.3))
        case 1:
            setZoomScale?(1.0)
        case 2:
            setZoomScale?(min(zoomScale * 1.1, 5.0))
        default:
            break
        }
    }

    @objc private func zoomOut() {
        setZoomScale?(max(zoomScale / 1.1, 0.3))
    }

    @objc private func printDocumentFromToolbar() {
        printDocument?()
    }

    @objc private func actualSize() {
        setZoomScale?(1.0)
    }

    @objc private func zoomIn() {
        setZoomScale?(min(zoomScale * 1.1, 5.0))
    }

    private func updateVisibleItems() {
        guard let toolbar = window?.toolbar else { return }
        for item in toolbar.items {
            switch item.itemIdentifier {
            case .toc:
                item.image = NSImage(systemSymbolName: tocVisible ? "list.bullet.circle.fill" : "list.bullet.circle", accessibilityDescription: "TOC")
                item.toolTip = tocVisible ? "Hide Table of Contents" : "Show Table of Contents"
                item.target = self
                item.action = #selector(toggleTOC)
                item.menuFormRepresentation = toolbarMenuItem(title: "TOC", action: #selector(toggleTOC), state: tocVisible ? .on : .off)
            case .tocDepth:
                if let popup = item.view as? NSPopUpButton {
                    popup.selectItem(at: max(0, min(5, tocDepth - 1)))
                    popup.isEnabled = tocVisible
                    popup.target = self
                    popup.action = #selector(tocDepthChanged(_:))
                }
                item.menuFormRepresentation = tocDepthMenuItem()
            case .markdownSource:
                item.image = NSImage(systemSymbolName: rawVisible ? "doc.plaintext.fill" : "doc.plaintext", accessibilityDescription: "Markdown Source")
                item.toolTip = rawVisible ? "Hide Markdown Source" : "Show Markdown Source"
                item.target = self
                item.action = #selector(toggleMarkdownSource)
                item.menuFormRepresentation = toolbarMenuItem(title: "Markdown Source", action: #selector(toggleMarkdownSource), state: rawVisible ? .on : .off)
            case .zoom:
                item.view = zoomControlView()
                item.menuFormRepresentation = zoomMenuItem()
            case .theme:
                if let popup = item.view as? NSPopUpButton {
                    popup.removeAllItems()
                    for theme in themeManager?.themes ?? [] {
                        popup.addItem(withTitle: theme.name)
                    }
                    popup.selectItem(withTitle: activeThemeName)
                    popup.target = self
                    popup.action = #selector(themeChanged(_:))
                }
                item.menuFormRepresentation = themeMenuItem()
            case .externalEditor:
                let replacement = makeExternalEditorItem()
                item.label = replacement.label
                item.paletteLabel = replacement.paletteLabel
                item.toolTip = replacement.toolTip
                item.image = replacement.image
                item.target = replacement.target
                item.action = replacement.action
                item.view = replacement.view
                item.menuFormRepresentation = replacement.menuFormRepresentation
                item.isEnabled = replacement.isEnabled
            default:
                break
            }
        }
    }
}

private extension NSToolbarItem.Identifier {
    static let toc = NSToolbarItem.Identifier("toc")
    static let tocDepth = NSToolbarItem.Identifier("toc-depth")
    static let markdownSource = NSToolbarItem.Identifier("markdown-source")
    static let zoom = NSToolbarItem.Identifier("zoom")
    static let theme = NSToolbarItem.Identifier("theme")
    static let externalEditor = NSToolbarItem.Identifier("external-editor")
    static let printDocument = NSToolbarItem.Identifier("print-document")
}

private extension NSToolbar.Identifier {
    static let documentToolbar = NSToolbar.Identifier("document-toolbar-v6")
}

private let legacyToolbarIdentifiers = [
    "document-toolbar",
    "document-toolbar-v2",
    "document-toolbar-v3",
    "document-toolbar-v4",
    "document-toolbar-v5"
]

private final class ZoomToolbarControlView: NSView {
    private let control: NSSegmentedControl

    init(control: NSSegmentedControl) {
        self.control = control
        super.init(frame: NSRect(origin: .zero, size: control.fittingSize))
        addSubview(control)
        setAccessibilityLabel("Zoom")
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: NSSize {
        control.intrinsicContentSize
    }

    override func layout() {
        super.layout()
        control.frame = bounds
    }
}

private struct FolderAccessBanner: View {
    let onGrant: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "photo.on.rectangle.angled")
            Text("Allow access to this file's folder to show images and auto-reload on changes.")
                .font(.callout)
            Spacer()
            Button("Allow Access…", action: onGrant)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.yellow.opacity(0.18))
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

extension NSView {
    func firstSubview<T: NSView>(ofType type: T.Type) -> T? {
        if let match = self as? T {
            return match
        }
        for subview in subviews {
            if let match = subview.firstSubview(ofType: type) {
                return match
            }
        }
        return nil
    }
}

/// A helper class to coordinate the print sheet operations in macOS.
/// Since SwiftUI's `ContentView` is a struct, it cannot receive `@objc` target-action messages.
/// This NSObject subclass serves as the delegate for `NSPrintOperation`, ensuring that when the
/// modal print sheet closes, the web view is cleanly restored to its screen theme/styles and
/// its manually-retained unmanaged reference pointer is released.
@MainActor
class PrintCoordinator: NSObject {
    weak var webView: WKWebView?
    let restoreCSS: String
    let stripBackgrounds: Bool
    let stripImages: Bool
    let stripWidth: Bool
    let printBorders: Bool
    let pagePadding: String

    init(webView: WKWebView, restoreCSS: String, stripBackgrounds: Bool, stripImages: Bool, stripWidth: Bool, printBorders: Bool, pagePadding: String) {
        self.webView = webView
        self.restoreCSS = restoreCSS
        self.stripBackgrounds = stripBackgrounds
        self.stripImages = stripImages
        self.stripWidth = stripWidth
        self.printBorders = printBorders
        self.pagePadding = pagePadding
        super.init()
    }

    /// Delegate callback executed by the macOS printing system after the print sheet runs.
    /// It restores visual screen settings and releases the retained coordinate pointer.
    @objc func printOperationDidRun(
        _ printOperation: NSPrintOperation,
        success: Bool,
        contextInfo: UnsafeMutableRawPointer?
    ) {
        restore()
        if let contextInfo = contextInfo {
            // Balance the manual passRetained call done at instantiation to prevent memory leaks.
            Unmanaged<PrintCoordinator>.fromOpaque(contextInfo).release()
        }
    }

    /// Restores the web view's CSS variables and removes active print classes.
    func restore() {
        guard let webView = webView else { return }
        let escapedCSS = restoreCSS.escapedForJavaScriptLiteral()
        let restoreJS = PrintScriptGenerator.restoreScript(
            escapedCSS: escapedCSS,
            stripBackgrounds: stripBackgrounds,
            stripImages: stripImages,
            stripWidth: stripWidth,
            printBorders: printBorders,
            pagePadding: pagePadding
        )
        webView.evaluateJavaScript(restoreJS, completionHandler: nil)
    }
}

/// Generates JavaScript commands for WebKit style updates during print operations.
struct PrintScriptGenerator {
    static func prepareScript(
        escapedCSS: String,
        stripBackgrounds: Bool,
        stripImages: Bool,
        stripWidth: Bool,
        printBorders: Bool,
        pagePadding: String
    ) -> String {
        let stripBackgroundsJS = stripBackgrounds ? "document.documentElement.classList.add('print-no-backgrounds');" : ""
        let stripImagesJS = stripImages ? "document.documentElement.classList.add('print-no-images');" : ""
        let fullWidthJS = stripWidth ? "document.documentElement.classList.add('print-full-width');" : ""
        let bordersJS = printBorders ? "document.documentElement.classList.add('print-borders');" : ""
        let paddingJS = "document.documentElement.style.setProperty('--print-padding', '\(pagePadding)');"
        return """
        document.getElementById('theme-css').textContent = '\(escapedCSS)';
        \(stripBackgroundsJS)
        \(stripImagesJS)
        \(fullWidthJS)
        \(bordersJS)
        \(paddingJS)
        void document.body.offsetHeight;
        """
    }

    static func restoreScript(
        escapedCSS: String,
        stripBackgrounds: Bool,
        stripImages: Bool,
        stripWidth: Bool,
        printBorders: Bool,
        pagePadding: String
    ) -> String {
        let removeBgJS = stripBackgrounds ? "document.documentElement.classList.remove('print-no-backgrounds');" : ""
        let removeImgJS = stripImages ? "document.documentElement.classList.remove('print-no-images');" : ""
        let removeWidthJS = stripWidth ? "document.documentElement.classList.remove('print-full-width');" : ""
        let removeBordersJS = printBorders ? "document.documentElement.classList.remove('print-borders');" : ""
        let removePaddingJS = "document.documentElement.style.removeProperty('--print-padding');"
        return """
        document.getElementById('theme-css').textContent = '\(escapedCSS)';
        \(removeBgJS)
        \(removeImgJS)
        \(removeWidthJS)
        \(removeBordersJS)
        \(removePaddingJS)
        """
    }
}

fileprivate extension String {
    func escapedForJavaScriptLiteral() -> String {
        self.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}

enum PrintZoomResolver {
    static func zoomScale(for printZoom: String, screenZoom: Double) -> Double {
        switch printZoom {
        case "Compact (75%)":
            return 0.75
        case "Small (85%)":
            return 0.85
        case "Standard (100%)":
            return 1.0
        case "Large (115%)":
            return 1.15
        case "Match Screen":
            return screenZoom
        default:
            return 1.0
        }
    }
}
