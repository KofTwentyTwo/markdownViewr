import Foundation
import SwiftUI

class ThemeManager: ObservableObject {
    @Published var themes: [Theme] = []
    @Published var activeThemeName: String {
        didSet {
            UserDefaults.standard.set(activeThemeName, forKey: "activeTheme")
        }
    }
    @Published var globalCSS: String {
        didSet {
            UserDefaults.standard.set(globalCSS, forKey: "globalCSS")
        }
    }
    @Published var zoomScale: Double {
        didSet {
            UserDefaults.standard.set(zoomScale, forKey: "zoomScale")
        }
    }
    @Published var frontmatterMode: MarkdownDocument.FrontmatterMode {
        didSet {
            UserDefaults.standard.set(frontmatterMode.rawValue, forKey: "frontmatterMode")
        }
    }

    var activeTheme: Theme {
        themes.first { $0.name == activeThemeName } ?? themes.first ?? Self.fallbackTheme
    }

    private static let fallbackTheme = Theme(name: "Default")

    init() {
        self.activeThemeName = UserDefaults.standard.string(forKey: "activeTheme") ?? "Catppuccin Mocha"
        self.globalCSS = UserDefaults.standard.string(forKey: "globalCSS") ?? ""
        let savedZoom = UserDefaults.standard.double(forKey: "zoomScale")
        self.zoomScale = savedZoom > 0 ? savedZoom : 1.0
        let modeRaw = UserDefaults.standard.string(forKey: "frontmatterMode") ?? "Hide"
        self.frontmatterMode = MarkdownDocument.FrontmatterMode(rawValue: modeRaw) ?? .hide
        loadThemes()
    }

    var disabledThemes: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "disabledThemes") ?? []) }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: "disabledThemes")
            objectWillChange.send()
        }
    }

    private var deletedBuiltIns: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "deletedBuiltIns") ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: "deletedBuiltIns") }
    }

    /// All visible themes (excluding deleted built-ins), including disabled ones — for settings UI
    @Published var allThemes: [Theme] = []

    var hasDeletedBuiltIns: Bool {
        !deletedBuiltIns.isEmpty
    }

    private var themeOrder: [String] {
        get { UserDefaults.standard.stringArray(forKey: "themeOrder") ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "themeOrder") }
    }

    func loadThemes() {
        let deleted = deletedBuiltIns
        var combined: [Theme] = []
        combined.append(contentsOf: loadBuiltInThemes().filter { !deleted.contains($0.name) })
        combined.append(contentsOf: loadUserThemes())

        let order = themeOrder
        if !order.isEmpty {
            combined.sort { a, b in
                let ai = order.firstIndex(of: a.name) ?? Int.max
                let bi = order.firstIndex(of: b.name) ?? Int.max
                if ai == bi { return a.name < b.name }
                return ai < bi
            }
        }

        self.allThemes = combined
        let disabled = disabledThemes
        self.themes = combined.filter { !disabled.contains($0.name) }
    }

    func moveThemeUp(name: String) {
        guard let index = allThemes.firstIndex(where: { $0.name == name }), index > 0 else { return }
        allThemes.swapAt(index, index - 1)
        themeOrder = allThemes.map(\.name)
        let disabled = disabledThemes
        themes = allThemes.filter { !disabled.contains($0.name) }
    }

    func moveThemeDown(name: String) {
        guard let index = allThemes.firstIndex(where: { $0.name == name }), index < allThemes.count - 1 else { return }
        allThemes.swapAt(index, index + 1)
        themeOrder = allThemes.map(\.name)
        let disabled = disabledThemes
        themes = allThemes.filter { !disabled.contains($0.name) }
    }

    func isThemeEnabled(_ name: String) -> Bool {
        !disabledThemes.contains(name)
    }

    func setThemeEnabled(_ name: String, enabled: Bool) {
        var disabled = disabledThemes
        if enabled {
            disabled.remove(name)
        } else {
            disabled.insert(name)
        }
        disabledThemes = disabled
        let d = disabledThemes
        themes = allThemes.filter { !d.contains($0.name) }
    }

    func restoreBuiltInThemes() {
        deletedBuiltIns = []
        disabledThemes = []
        loadThemes()
    }

    private func loadBuiltInThemes() -> [Theme] {
        let bundle = Bundle.main
        let urls: [URL]
        if let found = bundle.urls(forResourcesWithExtension: "json", subdirectory: nil) {
            urls = found
        } else {
            return []
        }

        let decoder = JSONDecoder()
        return urls.compactMap { url -> Theme? in
            guard let data = try? Data(contentsOf: url),
                  var theme = try? decoder.decode(Theme.self, from: data)
            else { return nil }
            theme.isBuiltIn = true
            return theme
        }.sorted { $0.name < $1.name }
    }

    private func loadUserThemes() -> [Theme] {
        let themesDir = Self.userThemesDirectory
        guard FileManager.default.fileExists(atPath: themesDir.path) else { return [] }

        let decoder = JSONDecoder()
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: themesDir,
            includingPropertiesForKeys: nil
        )) ?? []

        return urls
            .filter { $0.pathExtension == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      let theme = try? decoder.decode(Theme.self, from: data)
                else { return nil }
                return theme
            }
            .sorted { $0.name < $1.name }
    }

    func saveUserTheme(_ theme: Theme) throws {
        let themesDir = Self.userThemesDirectory
        try FileManager.default.createDirectory(at: themesDir, withIntermediateDirectories: true)

        let filename = theme.name
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()
            .appending(".json")
        let url = themesDir.appendingPathComponent(filename)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(theme)
        try data.write(to: url)

        loadThemes()
    }

    func zoomIn() {
        zoomScale = min(zoomScale * 1.1, 5.0)
    }

    func zoomOut() {
        zoomScale = max(zoomScale / 1.1, 0.3)
    }

    func zoomReset() {
        zoomScale = 1.0
    }

    func cycleTheme(direction: Int) {
        guard !themes.isEmpty else { return }
        let currentIndex = themes.firstIndex { $0.name == activeThemeName } ?? 0
        let newIndex = (currentIndex + direction + themes.count) % themes.count
        activeThemeName = themes[newIndex].name
    }

    func deleteTheme(_ theme: Theme) throws {
        if theme.isBuiltIn {
            var deleted = deletedBuiltIns
            deleted.insert(theme.name)
            deletedBuiltIns = deleted
        } else {
            let themesDir = Self.userThemesDirectory
            let filename = theme.name
                .replacingOccurrences(of: " ", with: "-")
                .lowercased()
                .appending(".json")
            let userFile = themesDir.appendingPathComponent(filename)
            if FileManager.default.fileExists(atPath: userFile.path) {
                try FileManager.default.removeItem(at: userFile)
            }
        }

        disabledThemes.remove(theme.name)
        loadThemes()
    }

    static var userThemesDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport
            .appendingPathComponent("markdownViewr")
            .appendingPathComponent("themes")
    }

    func generateCSS(for theme: Theme) -> String {
        let bodyFont = theme.fonts.body == "System"
            ? "-apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif"
            : "'\(theme.fonts.body)', -apple-system, sans-serif"

        let headingFont = theme.fonts.heading == "System"
            ? "-apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif"
            : "'\(theme.fonts.heading)', -apple-system, sans-serif"

        let codeFont = "'\(theme.fonts.code)', 'SF Mono', 'Menlo', 'Monaco', monospace"

        let z = zoomScale

        var css = """
        :root {
            --bg: \(theme.colors.background);
            --text: \(theme.colors.text);
            --h1: \(theme.colors.heading1);
            --h2: \(theme.colors.heading2);
            --h3: \(theme.colors.heading3);
            --h4: \(theme.colors.heading4);
            --h5: \(theme.colors.heading5);
            --h6: \(theme.colors.heading6);
            --link: \(theme.colors.link);
            --code-bg: \(theme.colors.codeBackground);
            --code-text: \(theme.colors.codeText);
            --blockquote-border: \(theme.colors.blockquoteBorder);
            --blockquote-bg: \(theme.colors.blockquoteBackground);
            --body-font: \(bodyFont);
            --heading-font: \(headingFont);
            --code-font: \(codeFont);
            --base-font-size: \(theme.sizes.baseFontSize * z)px;
            --h1-size: \(theme.sizes.h1Size * z)px;
            --h2-size: \(theme.sizes.h2Size * z)px;
            --h3-size: \(theme.sizes.h3Size * z)px;
            --h4-size: \(theme.sizes.h4Size * z)px;
            --h5-size: \(theme.sizes.h5Size * z)px;
            --h6-size: \(theme.sizes.h6Size * z)px;
            --code-font-size: \(theme.sizes.codeFontSize * z)px;
            --line-height: \(theme.sizes.lineHeight);
            --zoom: \(z);
        }
        """

        if !globalCSS.isEmpty {
            css += "\n\n/* Global CSS */\n\(globalCSS)"
        }

        if !theme.customCSS.isEmpty {
            css += "\n\n/* Theme CSS */\n\(theme.customCSS)"
        }

        return css
    }
}
