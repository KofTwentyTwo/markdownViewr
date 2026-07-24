import XCTest
import WebKit
@testable import markdownViewr

final class PrintingTests: XCTestCase {
    // 1. Unit Test for firstSubview(ofType:)
    func testNSViewFirstSubviewOfTypeRecurse() {
        let parent = NSView()
        let mid = NSView()
        let target = WKWebView()

        mid.addSubview(target)
        parent.addSubview(mid)

        // Assert we can find the WKWebView recursively
        let foundWebView = parent.firstSubview(ofType: WKWebView.self)
        XCTAssertNotNil(foundWebView)
        XCTAssertEqual(foundWebView, target)

        // Assert we find nil for a type that doesn't exist
        class CustomTestView: NSView {}
        XCTAssertNil(parent.firstSubview(ofType: CustomTestView.self))
    }

    // 2. Static Assertions on source files
    func testAppConfiguresReplacementPrintCommand() throws {
        let appSource = try loadSourceFile("markdownViewr/MarkdownViewrApp.swift")

        // Verify we replaced the default print command group
        XCTAssertTrue(appSource.contains("CommandGroup(replacing: .printItem)"))
        XCTAssertTrue(appSource.contains("documentViewCommands?.printDocument()"))
    }

    func testContentViewBindsPrintDocumentActionAndCoordinator() throws {
        let contentSource = try loadSourceFile("markdownViewr/ContentView.swift")

        // Verify printDocument is in DocumentViewCommands struct
        XCTAssertTrue(contentSource.contains("let printDocument: () -> Void"))
        // Verify printDocument is instantiated with printActiveDocument
        XCTAssertTrue(contentSource.contains("printDocument: { printActiveDocument() }"))
        // Verify printActiveDocument exists
        XCTAssertTrue(contentSource.contains("func printActiveDocument()"))
        // Verify recursive traversal is used to find WKWebView
        XCTAssertTrue(contentSource.contains("window.contentView?.firstSubview(ofType: WKWebView.self)"))

        // Verify print settings storage variables exist
        XCTAssertTrue(contentSource.contains(#"@AppStorage("printTheme") private var printTheme = "Clean Printing""#))
        XCTAssertTrue(contentSource.contains(#"@AppStorage("printBackgrounds") private var printBackgrounds = false"#))
        XCTAssertTrue(contentSource.contains(#"@AppStorage("printImages") private var printImages = true"#))
        XCTAssertTrue(contentSource.contains(#"@AppStorage("printZoom") private var printZoom = "Standard (100%)""#))
        XCTAssertTrue(contentSource.contains(#"@AppStorage("printContentWidth") private var printContentWidth = "Full Page""#))

        // Verify print coordinator instantiation passing all parameters
        XCTAssertTrue(contentSource.contains("let coordinator = PrintCoordinator("))
        XCTAssertTrue(contentSource.contains("stripBackgrounds: !printBackgroundsVal"))
        XCTAssertTrue(contentSource.contains("stripImages: !printImagesVal"))
        XCTAssertTrue(contentSource.contains("stripWidth: printContentWidthVal == \"Full Page\""))

        // Verify we run the print operation modally with coordinator pointer
        XCTAssertTrue(contentSource.contains("printOp.runModal("))
        XCTAssertTrue(contentSource.contains("didRun: #selector(PrintCoordinator.printOperationDidRun(_:success:contextInfo:))"))
        XCTAssertTrue(contentSource.contains("contextInfo: coordinatorPointer"))

        // Verify PrintCoordinator class exists, conforms to @MainActor and supports stripWidth
        XCTAssertTrue(contentSource.contains("@MainActor\nclass PrintCoordinator"))
        XCTAssertTrue(contentSource.contains("let stripImages: Bool"))
        XCTAssertTrue(contentSource.contains("let stripWidth: Bool"))
        XCTAssertTrue(contentSource.contains("func restore()"))
    }

    func testPrintOperationUsesCopiedPrintInfo() throws {
        let contentSource = try loadSourceFile("markdownViewr/ContentView.swift")

        XCTAssertTrue(contentSource.contains("NSPrintInfo.shared.copy() as? NSPrintInfo"))
        XCTAssertFalse(contentSource.contains("let printInfo = NSPrintInfo.shared\n"))
    }

    func testPrintToolbarItemIsAvailableForCustomization() throws {
        let contentSource = try loadSourceFile("markdownViewr/ContentView.swift")

        XCTAssertTrue(contentSource.contains("printDocument: @escaping () -> Void"))
        XCTAssertTrue(contentSource.contains("self.printDocument = printDocument"))
        XCTAssertTrue(contentSource.contains(".printDocument, .space"))
        XCTAssertFalse(contentSource.contains("return [.toc, .tocDepth, .printDocument"))
        XCTAssertTrue(contentSource.contains("case .printDocument:\n            return makePrintItem()"))
        XCTAssertTrue(contentSource.contains(#"item.label = "Print""#))
        XCTAssertTrue(contentSource.contains(#"item.paletteLabel = "Print""#))
        XCTAssertTrue(contentSource.contains(#"NSImage(systemSymbolName: "printer""#))
        XCTAssertTrue(contentSource.contains("item.action = #selector(printDocumentFromToolbar)"))
        XCTAssertTrue(contentSource.contains("@objc private func printDocumentFromToolbar()"))
        XCTAssertTrue(contentSource.contains("printDocument?()"))
        XCTAssertTrue(contentSource.contains(#"static let printDocument = NSToolbarItem.Identifier("print-document")"#))
    }

    func testXcodeGenConfigurationIncludesTestSources() throws {
        let projectSource = try loadSourceFile("project.yml")

        XCTAssertTrue(projectSource.contains("markdownViewrTests:"))
        XCTAssertTrue(projectSource.contains("- markdownViewrTests"))
    }

    func testSettingsViewIncludesPrintingTab() throws {
        let settingsSource = try loadSourceFile("markdownViewr/SettingsView.swift")

        // Verify PrintingSettingsView is declared in TabView
        XCTAssertTrue(settingsSource.contains("PrintingSettingsView()"))
        XCTAssertTrue(settingsSource.contains(#"Label("Printing", systemImage: "printer")"#))

        // Verify PrintingSettingsView struct layout
        XCTAssertTrue(settingsSource.contains("struct PrintingSettingsView: View"))
        XCTAssertTrue(settingsSource.contains(#"@AppStorage("printTheme") private var printTheme = "Clean Printing""#))
        XCTAssertTrue(settingsSource.contains(#"@AppStorage("printBackgrounds") private var printBackgrounds = false"#))
        XCTAssertTrue(settingsSource.contains(#"@AppStorage("printImages") private var printImages = true"#))
        XCTAssertTrue(settingsSource.contains(#"@AppStorage("printZoom") private var printZoom = "Standard (100%)""#))
        XCTAssertTrue(settingsSource.contains(#"@AppStorage("printContentWidth") private var printContentWidth = "Full Page""#))

        // Verify spacing and alignment matching HIG guidelines
        XCTAssertTrue(settingsSource.contains("VStack(alignment: .leading, spacing: 0)"))
        XCTAssertTrue(settingsSource.contains(".padding(.bottom, 16)"))
        XCTAssertTrue(settingsSource.contains(".padding(.top, 12)"))

        // Verify Settings Layout Components (splits and columns)
        XCTAssertTrue(settingsSource.contains("Picker("))
        XCTAssertTrue(settingsSource.contains(#"Text("Plain HTML (Unstyled)")"#))
        XCTAssertTrue(settingsSource.contains(#"Text("Clean Printing")"#))
        XCTAssertTrue(settingsSource.contains(#"GroupBox(label: Text("Print Theme"))"#))
        XCTAssertTrue(settingsSource.contains(#"GroupBox(label: Text("Page Layout"))"#))
        XCTAssertTrue(settingsSource.contains(#"GroupBox(label: Text("Zoom & Scaling"))"#))
        XCTAssertTrue(settingsSource.contains("Toggle("))
    }

    // 3. Template @media print assertion
    func testTemplateIncludesPrintMediaQueries() throws {
        let template = try loadTemplate()

        // Verify print media query exists
        XCTAssertTrue(template.contains("@media print"))

        let printBlock = try printMediaQueryBlock(in: template)

        // Verify print color adjust properties are present to preserve theme colors
        XCTAssertTrue(printBlock.contains("-webkit-print-color-adjust: exact !important"))
        XCTAssertTrue(printBlock.contains("print-color-adjust: exact !important"))

        // Verify print background toggling override style exists without wiping theme text colors
        XCTAssertTrue(printBlock.contains("html.print-no-backgrounds"))
        XCTAssertTrue(printBlock.contains("print-color-adjust: economy !important"))
        XCTAssertFalse(printBlock.contains("color: #000000 !important"))

        // Verify ink-saving layout overrides for links, rules, headers, and blockquotes
        XCTAssertTrue(printBlock.contains("html.print-no-backgrounds hr"))
        XCTAssertTrue(printBlock.contains("html.print-no-backgrounds blockquote"))
        XCTAssertTrue(printBlock.contains("html.print-no-backgrounds h1"))

        // Verify print image toggling override style targets specific content images
        XCTAssertTrue(printBlock.contains("html.print-no-images #content-inner img"))

        // Verify collapsed editor expansion rules
        XCTAssertTrue(printBlock.contains("#content-inner > *"))
        XCTAssertTrue(printBlock.contains("display: revert !important"))

        // Verify print full width toggling override style exists
        XCTAssertTrue(printBlock.contains("html.print-full-width #content-inner"))
        XCTAssertTrue(printBlock.contains("max-width: none !important"))

        // Verify layout overrides
        XCTAssertTrue(printBlock.contains("html, body"))
        XCTAssertTrue(printBlock.contains("height: auto !important"))
        XCTAssertTrue(printBlock.contains("overflow: visible !important"))

        XCTAssertTrue(printBlock.contains("#content"))

        // Verify elements hidden
        XCTAssertTrue(printBlock.contains("#toc"))
        XCTAssertTrue(printBlock.contains("#raw-source"))
        XCTAssertTrue(printBlock.contains(".collapse-arrow"))
        XCTAssertTrue(printBlock.contains("display: none !important"))
    }

    func testTemplatePrintStylesForEdgeCases() throws {
        let template = try loadTemplate()
        let printBlock = try printMediaQueryBlock(in: template)

        // 1. Heading Orphaning: Ensure headings (h1-h6) have CSS break-after avoid rules
        XCTAssertTrue(printBlock.contains("h1, h2, h3, h4, h5, h6 {"))
        XCTAssertTrue(printBlock.contains("break-after: avoid"))
        XCTAssertTrue(printBlock.contains("page-break-after: avoid"))

        // 2. Element Page Splits: Ensure small code blocks (pre/code), blockquotes, table rows, and list items have break-inside/page-break-inside avoid rules
        XCTAssertTrue(printBlock.contains("pre, blockquote, tr, li {"))
        XCTAssertTrue(printBlock.contains("break-inside: avoid"))
        XCTAssertTrue(printBlock.contains("page-break-inside: avoid"))

        // 3. Image Overflow: Ensure images do not exceed page boundaries and break-inside: avoid
        XCTAssertTrue(printBlock.contains("img {"))
        XCTAssertTrue(printBlock.contains("max-width: 100%"))

        // 4. Table Formatting: Ensure table headers repeat on page boundaries and headers/cells wrap text nicely
        XCTAssertTrue(printBlock.contains("thead {"))
        XCTAssertTrue(printBlock.contains("display: table-header-group"))
        XCTAssertTrue(printBlock.contains("th, td {"))
        XCTAssertTrue(printBlock.contains("word-wrap: break-word"))
        XCTAssertTrue(printBlock.contains("white-space: normal"))
    }

    func testPrintMediaQueriesPreserveThemeColorsInInkSavingMode() throws {
        let template = try loadTemplate()
        let printBlock = try printMediaQueryBlock(in: template)

        // Ensure print-no-backgrounds class does not apply universal color: #000000 !important
        // so that selected theme CSS variables (--h1, --h2, --link, --code-text, --text) apply during print.
        XCTAssertFalse(printBlock.contains("html.print-no-backgrounds * {\n        -webkit-print-color-adjust: economy !important;\n        print-color-adjust: economy !important;\n        background: transparent !important;\n        background-color: transparent !important;\n        background-image: none !important;\n        /* Avoid light text rendering on white backgrounds */\n        color: #000000 !important;\n    }"))
        XCTAssertFalse(printBlock.contains("html.print-no-backgrounds a {\n        color: #0969da !important;"))
    }

    func testPrintMediaQueriesEnforceThemeFontsSizesAndColors() throws {
        let template = try loadTemplate()
        let printBlock = try printMediaQueryBlock(in: template)

        // Verify fonts are explicitly bound in @media print
        XCTAssertTrue(printBlock.contains("var(--body-font) !important"))
        XCTAssertTrue(printBlock.contains("var(--base-font-size) !important"))
        XCTAssertTrue(printBlock.contains("var(--heading-font) !important"))
        XCTAssertTrue(printBlock.contains("var(--code-font) !important"))
        XCTAssertTrue(printBlock.contains("var(--code-font-size) !important"))

        // Verify heading sizes are explicitly bound in @media print
        XCTAssertTrue(printBlock.contains("var(--h1-size) !important"))
        XCTAssertTrue(printBlock.contains("var(--h2-size) !important"))
        XCTAssertTrue(printBlock.contains("var(--h3-size) !important"))
        XCTAssertTrue(printBlock.contains("var(--h4-size) !important"))
        XCTAssertTrue(printBlock.contains("var(--h5-size) !important"))
        XCTAssertTrue(printBlock.contains("var(--h6-size) !important"))

        // Verify colors are explicitly bound in @media print
        XCTAssertTrue(printBlock.contains("var(--h1) !important"))
        XCTAssertTrue(printBlock.contains("var(--h2) !important"))
        XCTAssertTrue(printBlock.contains("var(--h3) !important"))
        XCTAssertTrue(printBlock.contains("var(--h4) !important"))
        XCTAssertTrue(printBlock.contains("var(--h5) !important"))
        XCTAssertTrue(printBlock.contains("var(--h6) !important"))
        XCTAssertTrue(printBlock.contains("var(--link) !important"))
        XCTAssertTrue(printBlock.contains("var(--code-text) !important"))
        XCTAssertTrue(printBlock.contains("var(--code-bg) !important"))
        XCTAssertTrue(printBlock.contains("var(--blockquote-border) !important"))
        XCTAssertTrue(printBlock.contains("var(--blockquote-bg) !important"))
        XCTAssertTrue(printBlock.contains("var(--highlight-bg) !important"))
        XCTAssertTrue(printBlock.contains("var(--highlight-text) !important"))
    }

    func testPrintPrepareScriptForcesLayoutPass() {
        let script = PrintScriptGenerator.prepareScript(
            escapedCSS: "body { color: red; }",
            stripBackgrounds: false,
            stripImages: false,
            stripWidth: false,
            printBorders: false,
            pagePadding: "0px"
        )
        XCTAssertTrue(script.contains("document.body.offsetHeight;"))
    }

    // 4. Functional test for PrintCoordinator script building and memory cycles
    @MainActor
    func testPrintCoordinatorMemoryManagementAndRestore() {
        class MockWebView: WKWebView {
            var lastEvaluatedJavaScript: String?

            override func evaluateJavaScript(_ javaScriptString: String, completionHandler: ((Any?, Error?) -> Void)? = nil) {
                self.lastEvaluatedJavaScript = javaScriptString
                completionHandler?(nil, nil)
            }
        }

        let webView = MockWebView()
        var coordinator: PrintCoordinator? = PrintCoordinator(
            webView: webView,
            restoreCSS: "body { background: 'white'; }",
            stripBackgrounds: true,
            stripImages: true,
            stripWidth: true,
            printBorders: true,
            pagePadding: "48px"
        )

        weak var weakCoordinator = coordinator
        XCTAssertNotNil(weakCoordinator)

        // Pass retained pointer simulating print runModal contextInfo
        let pointer = Unmanaged.passRetained(coordinator!).toOpaque()

        // Release our strong local reference (ref count is now held only by the unmanaged pointer)
        coordinator = nil
        XCTAssertNotNil(weakCoordinator)

        // Simulate AppKit delegate execution finishing
        let dummyOperation = NSPrintOperation()
        weakCoordinator?.printOperationDidRun(dummyOperation, success: true, contextInfo: pointer)

        // Assert the unmanaged pointer is released and coordinator is deallocated
        XCTAssertNil(weakCoordinator)

        // Assert Javascript script execution occurred and escaped CSS correctly
        XCTAssertNotNil(webView.lastEvaluatedJavaScript)
        let js = webView.lastEvaluatedJavaScript!
        XCTAssertTrue(js.contains("document.getElementById('theme-css').textContent = 'body { background: \\'white\\'; }';"))
        XCTAssertTrue(js.contains("document.documentElement.classList.remove('print-no-backgrounds');"))
        XCTAssertTrue(js.contains("document.documentElement.classList.remove('print-no-images');"))
        XCTAssertTrue(js.contains("document.documentElement.classList.remove('print-full-width');"))
        XCTAssertTrue(js.contains("document.documentElement.classList.remove('print-borders');"))
        XCTAssertTrue(js.contains("document.documentElement.style.removeProperty('--print-padding');"))
    }

    func testCleanPrintingThemeIsBuiltInAndIndependent() {
        let theme = Theme.cleanPrinting
        XCTAssertEqual(theme.name, "Clean Printing")
        XCTAssertTrue(theme.isBuiltIn)
        XCTAssertEqual(theme.colors.background, "#ffffff")
        XCTAssertEqual(theme.colors.text, "#24292e")
    }

    // 5. Test that template print query stylesheet contains the print-borders rules
    func testTemplatePrintStylesForBorders() throws {
        let template = try loadTemplate()
        let printBlock = try printMediaQueryBlock(in: template)

        XCTAssertTrue(printBlock.contains("html.print-borders pre"))
        XCTAssertTrue(printBlock.contains("html.print-borders .frontmatter"))
        XCTAssertTrue(printBlock.contains("html.print-borders blockquote"))
        XCTAssertTrue(printBlock.contains("html.print-borders code"))
    }

    // 6. Test that PrintScriptGenerator outputs correct prepare and restore scripts
    func testPrintScriptGeneratorScriptOutputs() {
        let prepareScript = PrintScriptGenerator.prepareScript(
            escapedCSS: "body { background: 'white'; }",
            stripBackgrounds: true,
            stripImages: true,
            stripWidth: true,
            printBorders: true,
            pagePadding: "48px"
        )

        XCTAssertTrue(prepareScript.contains("document.getElementById('theme-css').textContent = 'body { background: \'white\'; }';"))
        XCTAssertTrue(prepareScript.contains("document.documentElement.classList.add('print-no-backgrounds');"))
        XCTAssertTrue(prepareScript.contains("document.documentElement.classList.add('print-no-images');"))
        XCTAssertTrue(prepareScript.contains("document.documentElement.classList.add('print-full-width');"))
        XCTAssertTrue(prepareScript.contains("document.documentElement.classList.add('print-borders');"))
        XCTAssertTrue(prepareScript.contains("document.documentElement.style.setProperty('--print-padding', '48px');"))

        let restoreScript = PrintScriptGenerator.restoreScript(
            escapedCSS: "body { background: 'dark'; }",
            stripBackgrounds: true,
            stripImages: true,
            stripWidth: true,
            printBorders: true,
            pagePadding: "48px"
        )

        XCTAssertTrue(restoreScript.contains("document.getElementById('theme-css').textContent = 'body { background: \'dark\'; }';"))
        XCTAssertTrue(restoreScript.contains("document.documentElement.classList.remove('print-no-backgrounds');"))
        XCTAssertTrue(restoreScript.contains("document.documentElement.classList.remove('print-no-images');"))
        XCTAssertTrue(restoreScript.contains("document.documentElement.classList.remove('print-full-width');"))
        XCTAssertTrue(restoreScript.contains("document.documentElement.classList.remove('print-borders');"))
        XCTAssertTrue(restoreScript.contains("document.documentElement.style.removeProperty('--print-padding');"))
    }

    // Helper function to read source files
    private func loadSourceFile(_ relativePath: String) throws -> String {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceURL = repoRoot.appendingPathComponent(relativePath)
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }

    // Helper function to read HTML template
    private func loadTemplate() throws -> String {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repoRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let templateURL = repoRoot.appendingPathComponent("markdownViewr/Resources/template.html")
        return try String(contentsOf: templateURL, encoding: .utf8)
    }

    // Helper function to extract @media print block
    private func printMediaQueryBlock(in template: String) throws -> String {
        let start = try XCTUnwrap(template.range(of: "@media print {"))
        let remainder = template[start.upperBound...]

        var bracketCount = 1
        var index = remainder.startIndex

        while bracketCount > 0 && index < remainder.endIndex {
            let char = remainder[index]
            if char == "{" {
                bracketCount += 1
            } else if char == "}" {
                bracketCount -= 1
            }
            if bracketCount > 0 {
                index = remainder.index(after: index)
            }
        }

        return String(remainder[..<index])
    }
}
