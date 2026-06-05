import SwiftUI
import UniformTypeIdentifiers
import Markdown

struct MarkdownDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [
            UTType(filenameExtension: "md") ?? .plainText,
            UTType(filenameExtension: "markdown") ?? .plainText,
            UTType(filenameExtension: "mdown") ?? .plainText,
            UTType(filenameExtension: "mkd") ?? .plainText,
            .plainText
        ]
    }

    var rawMarkdown: String
    var html: String

    init() {
        self.rawMarkdown = ""
        self.html = ""
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.rawMarkdown = text
        self.html = MarkdownDocument.convertToHTML(text)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(rawMarkdown.utf8)
        return .init(regularFileWithContents: data)
    }

    enum FrontmatterMode: String, CaseIterable {
        case hide = "Hide"
        case metadata = "Show as Metadata"
        case markdown = "Show as Markdown"
    }

    static func convertToHTML(_ markdown: String, frontmatterMode: FrontmatterMode = .hide, extensions: MarkdownExtensions = MarkdownExtensions()) -> String {
        let (frontmatter, body) = parseFrontmatter(markdown)

        var html = ""

        if let frontmatter, !frontmatter.isEmpty {
            switch frontmatterMode {
            case .hide:
                break
            case .metadata:
                html += renderFrontmatterAsMetadata(frontmatter)
            case .markdown:
                html += renderFrontmatterAsMarkdown(frontmatter)
            }
        }

        let content = frontmatter != nil ? body : markdown
        let document = Document(parsing: content)
        var htmlVisitor = HTMLConverter()
        html += htmlVisitor.visit(document)
        return applyExtensions(html, extensions: extensions)
    }

    private static func parseFrontmatter(_ markdown: String) -> (frontmatter: String?, body: String) {
        let trimmed = markdown.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("---") else { return (nil, markdown) }

        let lines = markdown.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else { return (nil, markdown) }

        var endIndex: Int?
        for i in 1..<lines.count {
            if lines[i].trimmingCharacters(in: .whitespaces) == "---" {
                endIndex = i
                break
            }
        }

        guard let end = endIndex else { return (nil, markdown) }

        let frontmatterLines = lines[1..<end]
        let bodyLines = lines[(end + 1)...]
        return (frontmatterLines.joined(separator: "\n"), bodyLines.joined(separator: "\n"))
    }

    private static func renderFrontmatterAsMetadata(_ yaml: String) -> String {
        var rows = ""
        for line in yaml.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if let colonIndex = trimmed.firstIndex(of: ":") {
                let key = stripMarkdownFormatting(String(trimmed[trimmed.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces))
                let value = stripMarkdownFormatting(String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces))
                rows += "<tr><td class=\"fm-key\">\(escapeHTML(key))</td><td class=\"fm-value\">\(escapeHTML(value))</td></tr>\n"
            } else {
                rows += "<tr><td class=\"fm-value\" colspan=\"2\">\(escapeHTML(stripMarkdownFormatting(trimmed)))</td></tr>\n"
            }
        }
        return "<div class=\"frontmatter\"><table>\(rows)</table></div>\n"
    }

    private static func stripMarkdownFormatting(_ text: String) -> String {
        var result = text
        // Bold/italic markers
        result = result.replacingOccurrences(of: "***", with: "")
        result = result.replacingOccurrences(of: "**", with: "")
        result = result.replacingOccurrences(of: "__", with: "")
        result = result.replacingOccurrences(of: "~~", with: "")
        // Single markers (but not mid-word apostrophes)
        if result.hasPrefix("*") && result.hasSuffix("*") {
            result = String(result.dropFirst().dropLast())
        }
        if result.hasPrefix("_") && result.hasSuffix("_") {
            result = String(result.dropFirst().dropLast())
        }
        // Inline code
        if result.hasPrefix("`") && result.hasSuffix("`") {
            result = String(result.dropFirst().dropLast())
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    private static func renderFrontmatterAsMarkdown(_ yaml: String) -> String {
        let document = Document(parsing: "---\n\(yaml)\n---")
        var htmlVisitor = HTMLConverter()
        return htmlVisitor.visit(document)
    }

    private static func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func applyExtensions(_ html: String, extensions: MarkdownExtensions) -> String {
        // Split on <pre...> tags (with optional attributes) so code blocks are never transformed.
        guard let preOpenRegex = try? NSRegularExpression(pattern: "<pre(?:\\s[^>]*)?>", options: []) else {
            return applyExtensionRegexes(html, extensions: extensions)
        }

        var result = ""
        var searchRange = html.startIndex..<html.endIndex

        while let match = preOpenRegex.firstMatch(in: html, range: NSRange(searchRange, in: html)) {
            guard let matchRange = Range(match.range, in: html) else { break }

            // Process text before this <pre...> tag
            let before = String(html[searchRange.lowerBound..<matchRange.lowerBound])
            result += applyExtensionRegexes(before, extensions: extensions)

            // Find the matching </pre>
            let afterOpenTag = matchRange.upperBound
            if let closeRange = html.range(of: "</pre>", range: afterOpenTag..<html.endIndex) {
                // Include the <pre...>content</pre> verbatim
                result += String(html[matchRange.lowerBound..<closeRange.upperBound])
                searchRange = closeRange.upperBound..<html.endIndex
            } else {
                // No closing </pre> found — pass through the rest verbatim
                result += String(html[matchRange.lowerBound...])
                return result
            }
        }

        // Process any remaining text after the last </pre>
        result += applyExtensionRegexes(String(html[searchRange]), extensions: extensions)
        return result
    }

    private static func applyExtensionRegexes(_ text: String, extensions: MarkdownExtensions) -> String {
        var result = text
        if extensions.highlight {
            result = applyRegex(result, pattern: "==(.+?)==", template: "<mark>$1</mark>")
        }
        if extensions.superscript {
            result = applyRegex(result, pattern: "\\^(.+?)\\^", template: "<sup>$1</sup>")
        }
        if extensions.subscript_ {
            // ~~text~~ is rendered as <del>text</del> by the parser before this runs,
            // so there are no bare ~~ sequences left to conflict with single-~ subscript.
            result = applyRegex(result, pattern: "~(.+?)~", template: "<sub>$1</sub>")
        }
        if extensions.underline {
            result = applyRegex(result, pattern: "\\+\\+(.+?)\\+\\+", template: "<ins>$1</ins>")
        }
        return result
    }

    private static func applyRegex(_ text: String, pattern: String, template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }
}

private struct HTMLConverter: MarkupWalker {
    private var result = ""

    mutating func visit(_ document: Document) -> String {
        result = ""
        for child in document.children {
            visitChild(child)
        }
        return result
    }

    private mutating func visitChild(_ markup: any Markup) {
        switch markup {
        case let heading as Heading:
            let level = heading.level
            result += "<h\(level)>"
            for child in heading.children {
                visitInline(child)
            }
            result += "</h\(level)>\n"

        case let paragraph as Paragraph:
            result += "<p>"
            for child in paragraph.children {
                visitInline(child)
            }
            result += "</p>\n"

        case let codeBlock as CodeBlock:
            let lang = codeBlock.language ?? ""
            if lang.isEmpty {
                result += "<pre><code>"
            } else {
                result += "<pre><code class=\"language-\(lang)\">"
            }
            result += escapeHTML(codeBlock.code)
            result += "</code></pre>\n"

        case let blockQuote as BlockQuote:
            result += "<blockquote>\n"
            for child in blockQuote.children {
                visitChild(child)
            }
            result += "</blockquote>\n"

        case let list as UnorderedList:
            result += "<ul>\n"
            for item in list.listItems {
                result += "<li>"
                for child in item.children {
                    if child is Paragraph {
                        for inline in child.children {
                            visitInline(inline)
                        }
                    } else {
                        visitChild(child)
                    }
                }
                result += "</li>\n"
            }
            result += "</ul>\n"

        case let list as OrderedList:
            let start = list.startIndex
            if start != 1 {
                result += "<ol start=\"\(start)\">\n"
            } else {
                result += "<ol>\n"
            }
            for item in list.listItems {
                result += "<li>"
                for child in item.children {
                    if child is Paragraph {
                        for inline in child.children {
                            visitInline(inline)
                        }
                    } else {
                        visitChild(child)
                    }
                }
                result += "</li>\n"
            }
            result += "</ol>\n"

        case let thematicBreak as ThematicBreak:
            _ = thematicBreak
            result += "<hr>\n"

        case let htmlBlock as HTMLBlock:
            result += htmlBlock.rawHTML

        case let table as Markdown.Table:
            result += "<table>\n<thead>\n<tr>\n"
            for cell in table.head.cells {
                let align = cell.colspan > 0 ? "" : ""
                result += "<th\(align)>"
                for child in cell.children {
                    visitInline(child)
                }
                result += "</th>\n"
            }
            result += "</tr>\n</thead>\n"
            if table.body.childCount > 0 {
                result += "<tbody>\n"
                for row in table.body.rows {
                    result += "<tr>\n"
                    for cell in row.cells {
                        result += "<td>"
                        for child in cell.children {
                            visitInline(child)
                        }
                        result += "</td>\n"
                    }
                    result += "</tr>\n"
                }
                result += "</tbody>\n"
            }
            result += "</table>\n"

        default:
            for child in markup.children {
                visitChild(child)
            }
        }
    }

    private mutating func visitInline(_ markup: any Markup) {
        switch markup {
        case let text as Markdown.Text:
            result += escapeHTML(text.string)

        case let strong as Strong:
            result += "<strong>"
            for child in strong.children {
                visitInline(child)
            }
            result += "</strong>"

        case let emphasis as Emphasis:
            result += "<em>"
            for child in emphasis.children {
                visitInline(child)
            }
            result += "</em>"

        case let code as InlineCode:
            result += "<code>"
            result += escapeHTML(code.code)
            result += "</code>"

        case let link as Markdown.Link:
            let dest = link.destination ?? ""
            result += "<a href=\"\(escapeHTML(dest))\">"
            for child in link.children {
                visitInline(child)
            }
            result += "</a>"

        case let image as Markdown.Image:
            let src = image.source ?? ""
            let alt = image.plainText
            result += "<img src=\"\(escapeHTML(src))\" alt=\"\(escapeHTML(alt))\">"

        case _ as SoftBreak:
            result += "\n"

        case _ as LineBreak:
            result += "<br>"

        case let html as InlineHTML:
            result += html.rawHTML

        case let strikethrough as Strikethrough:
            result += "<del>"
            for child in strikethrough.children {
                visitInline(child)
            }
            result += "</del>"

        default:
            for child in markup.children {
                visitInline(child)
            }
        }
    }

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
