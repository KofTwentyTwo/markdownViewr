import Foundation
import SwiftUI

struct Theme: Codable, Identifiable, Hashable {
    static let currentSchemaVersion = 1

    var id: String { name }

    var schemaVersion: Int = 1
    var name: String
    var colors: ThemeColors
    var fonts: ThemeFonts
    var sizes: ThemeSizes
    var customCSS: String

    /// Runtime-only flag, not persisted in JSON
    var isBuiltIn: Bool = false

    enum CodingKeys: String, CodingKey {
        case schemaVersion, name, colors, fonts, sizes, customCSS
    }

    init(
        name: String,
        colors: ThemeColors = ThemeColors(),
        fonts: ThemeFonts = ThemeFonts(),
        sizes: ThemeSizes = ThemeSizes(),
        customCSS: String = "",
        isBuiltIn: Bool = false
    ) {
        self.schemaVersion = Self.currentSchemaVersion
        self.name = name
        self.colors = colors
        self.fonts = fonts
        self.sizes = sizes
        self.customCSS = customCSS
        self.isBuiltIn = isBuiltIn
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        name = try c.decode(String.self, forKey: .name)
        colors = try c.decode(ThemeColors.self, forKey: .colors)
        fonts = try c.decode(ThemeFonts.self, forKey: .fonts)
        sizes = try c.decode(ThemeSizes.self, forKey: .sizes)
        customCSS = try c.decodeIfPresent(String.self, forKey: .customCSS) ?? ""
    }
}

struct ThemeColors: Codable, Hashable {
    var background: String
    var text: String
    var heading1: String
    var heading2: String
    var heading3: String
    var heading4: String
    var heading5: String
    var heading6: String
    var link: String
    var codeBackground: String
    var codeText: String
    var blockquoteBorder: String
    var blockquoteBackground: String
    var highlightBackground: String
    var highlightText: String

    init(
        background: String = "#1e1e2e",
        text: String = "#cdd6f4",
        heading1: String = "#cba6f7",
        heading2: String = "#89b4fa",
        heading3: String = "#89b4fa",
        heading4: String = "#74c7ec",
        heading5: String = "#74c7ec",
        heading6: String = "#74c7ec",
        link: String = "#89dceb",
        codeBackground: String = "#181825",
        codeText: String = "#a6e3a1",
        blockquoteBorder: String = "#cba6f7",
        blockquoteBackground: String = "#252535",
        highlightBackground: String = "#ffd700",
        highlightText: String = "#1a1a1a"
    ) {
        self.background = background
        self.text = text
        self.heading1 = heading1
        self.heading2 = heading2
        self.heading3 = heading3
        self.heading4 = heading4
        self.heading5 = heading5
        self.heading6 = heading6
        self.link = link
        self.codeBackground = codeBackground
        self.codeText = codeText
        self.blockquoteBorder = blockquoteBorder
        self.blockquoteBackground = blockquoteBackground
        self.highlightBackground = highlightBackground
        self.highlightText = highlightText
    }

    enum CodingKeys: String, CodingKey {
        case background, text
        case heading1, heading2, heading3, heading4, heading5, heading6
        case link, codeBackground, codeText
        case blockquoteBorder, blockquoteBackground
        case highlightBackground, highlightText
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        background = try c.decode(String.self, forKey: .background)
        text = try c.decode(String.self, forKey: .text)
        heading1 = try c.decode(String.self, forKey: .heading1)
        heading2 = try c.decode(String.self, forKey: .heading2)
        heading3 = try c.decode(String.self, forKey: .heading3)
        heading4 = try c.decode(String.self, forKey: .heading4)
        heading5 = try c.decode(String.self, forKey: .heading5)
        heading6 = try c.decode(String.self, forKey: .heading6)
        link = try c.decode(String.self, forKey: .link)
        codeBackground = try c.decode(String.self, forKey: .codeBackground)
        codeText = try c.decode(String.self, forKey: .codeText)
        blockquoteBorder = try c.decode(String.self, forKey: .blockquoteBorder)
        blockquoteBackground = try c.decode(String.self, forKey: .blockquoteBackground)
        highlightBackground = try c.decodeIfPresent(String.self, forKey: .highlightBackground) ?? "#ffd700"
        highlightText = try c.decodeIfPresent(String.self, forKey: .highlightText) ?? "#1a1a1a"
    }
}

struct ThemeFonts: Codable, Hashable {
    var body: String
    var heading: String
    var code: String

    init(body: String = "System", heading: String = "System", code: String = "SF Mono") {
        self.body = body
        self.heading = heading
        self.code = code
    }
}

struct ThemeSizes: Codable, Hashable {
    var baseFontSize: Double
    var h1Size: Double
    var h2Size: Double
    var h3Size: Double
    var h4Size: Double
    var h5Size: Double
    var h6Size: Double
    var codeFontSize: Double
    var lineHeight: Double

    init(
        baseFontSize: Double = 14,
        h1Size: Double = 28,
        h2Size: Double = 23,
        h3Size: Double = 20,
        h4Size: Double = 18,
        h5Size: Double = 16,
        h6Size: Double = 15,
        codeFontSize: Double = 13,
        lineHeight: Double = 1.7
    ) {
        self.baseFontSize = baseFontSize
        self.h1Size = h1Size
        self.h2Size = h2Size
        self.h3Size = h3Size
        self.h4Size = h4Size
        self.h5Size = h5Size
        self.h6Size = h6Size
        self.codeFontSize = codeFontSize
        self.lineHeight = lineHeight
    }
}

extension Theme {
    static let cleanPrinting = Theme(
        name: "Clean Printing",
        colors: ThemeColors(
            background: "#ffffff",
            text: "#24292e",
            heading1: "#1b1f23",
            heading2: "#1b1f23",
            heading3: "#1b1f23",
            heading4: "#1b1f23",
            heading5: "#1b1f23",
            heading6: "#1b1f23",
            link: "#0366d6",
            codeBackground: "#f6f8fa",
            codeText: "#24292e",
            blockquoteBorder: "#dfe2e5",
            blockquoteBackground: "#fafbfc",
            highlightBackground: "#fff5b1",
            highlightText: "#24292e"
        ),
        fonts: ThemeFonts(body: "System", heading: "System", code: "SF Mono"),
        sizes: ThemeSizes(
            baseFontSize: 11,
            h1Size: 22,
            h2Size: 18,
            h3Size: 15,
            h4Size: 13.5,
            h5Size: 12,
            h6Size: 11,
            codeFontSize: 10.5,
            lineHeight: 1.5
        ),
        customCSS: "",
        isBuiltIn: true
    )
}

