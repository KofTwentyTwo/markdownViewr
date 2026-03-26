import SwiftUI
import WebKit
import Combine

struct MarkdownWebView: NSViewRepresentable {
    let html: String
    let themeCSS: String
    var fileURL: URL?
    var findBar: FindBarController?
    var tocVisible: Bool = false
    var tocDepth: Int = 3

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "developerExtrasEnabled")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        loadContent(in: webView, context: context)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if context.coordinator.lastHTML != html {
            let previousHTML = context.coordinator.lastHTML
            context.coordinator.lastHTML = html
            context.coordinator.lastCSS = themeCSS

            if previousHTML.isEmpty {
                loadContent(in: webView, context: context)
            } else {
                updateContent(in: webView)
            }
        } else if context.coordinator.lastCSS != themeCSS {
            context.coordinator.lastCSS = themeCSS
            injectCSS(in: webView)
        }

        if context.coordinator.lastTocVisible != tocVisible {
            context.coordinator.lastTocVisible = tocVisible
            webView.evaluateJavaScript("setTOCVisible(\(tocVisible))") { _, _ in }
        }
        if context.coordinator.lastTocDepth != tocDepth {
            context.coordinator.lastTocDepth = tocDepth
            webView.evaluateJavaScript("setTOCDepth(\(tocDepth))") { _, _ in }
        }
    }

    private static let previewDirectory: URL = {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("markdownViewr-previews")
        return tmp
    }()

    func makeCoordinator() -> Coordinator {
        Coordinator(findBar: findBar)
    }

    private func loadContent(in webView: WKWebView, context: Context) {
        guard let templateURL = Bundle.main.url(forResource: "template", withExtension: "html"),
              var template = try? String(contentsOf: templateURL, encoding: .utf8)
        else {
            webView.loadHTMLString("<p>Failed to load template</p>", baseURL: nil)
            return
        }

        context.coordinator.lastHTML = html
        context.coordinator.lastCSS = themeCSS
        if let fileDir = fileURL?.deletingLastPathComponent() {
            template = template.replacingOccurrences(of: "{{BASE_TAG}}", with: "<base href=\"\(fileDir.absoluteString)\">")
        } else {
            template = template.replacingOccurrences(of: "{{BASE_TAG}}", with: "")
        }
        template = template.replacingOccurrences(of: "{{THEME_CSS}}", with: themeCSS)
        template = template.replacingOccurrences(of: "{{CONTENT}}", with: html)

        if let fileDir = fileURL?.deletingLastPathComponent() {
            let tempDir = Self.previewDirectory
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let tempHTML = tempDir.appendingPathComponent(UUID().uuidString + ".html")
            try? template.write(to: tempHTML, atomically: true, encoding: .utf8)
            // Grant read access to "/" so both the temp file and the document's images are accessible
            webView.loadFileURL(tempHTML, allowingReadAccessTo: URL(fileURLWithPath: "/"))
            context.coordinator.tempFileURL = tempHTML
        } else {
            webView.loadHTMLString(template, baseURL: nil)
        }

        // Queue TOC state to apply after page loads
        context.coordinator.pendingTocVisible = tocVisible
        context.coordinator.pendingTocDepth = tocDepth
    }

    private func updateContent(in webView: WKWebView) {
        let escaped = html
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
        let js = "updateContent(`\(escaped)`);"
        webView.evaluateJavaScript(js) { _, error in
            if let error {
                print("Content update error: \(error)")
            }
        }
    }

    private func injectCSS(in webView: WKWebView) {
        let escapedCSS = themeCSS
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
        webView.evaluateJavaScript("updateThemeCSS('\(escapedCSS)')") { _, error in
            if let error {
                print("Theme update error: \(error)")
            }
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var webView: WKWebView?
        var lastHTML: String = ""
        var lastCSS: String = ""
        var lastTocVisible: Bool = false
        var lastTocDepth: Int = 3
        var pendingTocVisible: Bool?
        var pendingTocDepth: Int?
        var tempFileURL: URL?
        private var findBarObservation: Any?
        private var lastSearchText: String = ""

        weak var findBar: FindBarController?

        init(findBar: FindBarController?) {
            self.findBar = findBar
            super.init()
            guard let findBar else { return }

            findBar.onFindNext = { [weak self] in
                self?.findNext()
            }
            findBar.onFindPrevious = { [weak self] in
                self?.findPrevious()
            }

            findBarObservation = findBar.$searchText
                .debounce(for: .milliseconds(150), scheduler: RunLoop.main)
                .sink { [weak self] text in
                    guard let self else { return }
                    if text.isEmpty {
                        self.clearFind()
                    } else {
                        self.lastSearchText = text
                        self.findAll(text)
                    }
                }
        }

        private func findAll(_ text: String) {
            guard let webView else { return }
            let escaped = text
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
            webView.evaluateJavaScript("findAll('\(escaped)')") { [weak self] result, _ in
                self?.updateFindStatus(result)
            }
        }

        private func findNext() {
            guard let webView else { return }
            webView.evaluateJavaScript("findNext()") { [weak self] result, _ in
                self?.updateFindStatus(result)
            }
        }

        private func findPrevious() {
            guard let webView else { return }
            webView.evaluateJavaScript("findPrev()") { [weak self] result, _ in
                self?.updateFindStatus(result)
            }
        }

        private func clearFind() {
            guard let webView else { return }
            webView.evaluateJavaScript("clearFind()") { _, _ in }
            DispatchQueue.main.async { [weak self] in
                self?.findBar?.matchStatus = nil
            }
        }

        private func updateFindStatus(_ result: Any?) {
            guard let json = result as? String,
                  let data = json.data(using: .utf8),
                  let status = try? JSONDecoder().decode(FindStatus.self, from: data)
            else { return }
            DispatchQueue.main.async { [weak self] in
                self?.findBar?.matchStatus = status
            }
        }

        deinit {
            if let url = tempFileURL {
                try? FileManager.default.removeItem(at: url)
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if navigationAction.navigationType == .linkActivated,
               let url = navigationAction.request.url {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let visible = pendingTocVisible {
                lastTocVisible = visible
                webView.evaluateJavaScript("setTOCVisible(\(visible))") { _, _ in }
                pendingTocVisible = nil
            }
            if let depth = pendingTocDepth {
                lastTocDepth = depth
                webView.evaluateJavaScript("setTOCDepth(\(depth))") { _, _ in }
                pendingTocDepth = nil
            }
        }
    }
}
