import SwiftUI

struct CSSHelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CSS Reference")
                .font(.headline)

            Group {
                Text("Structure")
                    .font(.subheadline).bold()
                codeBlock("""
                body
                  div#content
                    div.frontmatter > table > tr
                      > td.fm-key, td.fm-value
                    h1, h2, h3, h4, h5, h6
                      > span.collapse-arrow
                    h1.collapsed, h2.collapsed, ...
                    p, ul, ol, blockquote, hr
                    pre > code
                    table > thead/tbody > tr > th/td
                    img
                """)
            }

            Group {
                Text("Code Blocks")
                    .font(.subheadline).bold()
                Text("Fenced code blocks get a language class:")
                    .font(.caption)
                codeBlock("pre code.language-swift { ... }")
            }

            Group {
                Text("CSS Variables")
                    .font(.subheadline).bold()
                Text("You can reference theme variables:")
                    .font(.caption)
                codeBlock("""
                var(--bg)  var(--text)  var(--link)
                var(--h1) .. var(--h6)
                var(--code-bg)  var(--code-text)
                var(--blockquote-border)
                var(--blockquote-bg)
                var(--body-font)  var(--heading-font)
                var(--code-font)
                var(--base-font-size)
                var(--h1-size) .. var(--h6-size)
                var(--code-font-size)  var(--line-height)
                var(--zoom)
                """)
            }

            Group {
                Text("Examples")
                    .font(.subheadline).bold()
                codeBlock("""
                /* Remove heading underlines */
                h1, h2 { border-bottom: none; }

                /* Custom link hover */
                a:hover { color: var(--h1); }

                /* Rounded images */
                img { border-radius: 12px; }
                """)
            }
        }
        .font(.caption)
        .padding(16)
        .frame(width: 320)
    }

    private func codeBlock(_ code: String) -> some View {
        Text(code)
            .font(.system(.caption2, design: .monospaced))
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary)
            .cornerRadius(6)
    }
}
