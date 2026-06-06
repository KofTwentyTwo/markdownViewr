import SwiftUI
import Sparkle

@main
struct MarkdownViewrApp: App {
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var editorManager = EditorManager()

    var body: some Scene {
        DocumentGroup(viewing: MarkdownDocument.self) { file in
            ContentView(
                document: file.$document,
                fileURL: file.fileURL
            )
            .environmentObject(themeManager)
            .environmentObject(editorManager)
            .background(DocumentWindowConfigurator(fileURL: file.fileURL))
        }
        .defaultSize(width: 700, height: 900)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    updaterController.checkForUpdates(nil)
                }
            }

            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    SettingsWindowController.shared.show(
                        themeManager: themeManager,
                        editorManager: editorManager
                    )
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandGroup(replacing: .textEditing) {
                Button("Find...") {
                    NotificationCenter.default.post(name: .findToggle, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("Find Next") {
                    NotificationCenter.default.post(name: .findNext, object: nil)
                }
                .keyboardShortcut("g", modifiers: .command)

                Button("Find Previous") {
                    NotificationCenter.default.post(name: .findPrevious, object: nil)
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .toolbar) {
                Button("Zoom In") {
                    themeManager.zoomIn()
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Zoom Out") {
                    themeManager.zoomOut()
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Actual Size") {
                    themeManager.zoomReset()
                }
                .keyboardShortcut("0", modifiers: .command)
            }

            CommandMenu("Theme") {
                Button("Next Theme") {
                    themeManager.cycleTheme(direction: 1)
                }
                .keyboardShortcut(.downArrow, modifiers: [.command, .shift])

                Button("Previous Theme") {
                    themeManager.cycleTheme(direction: -1)
                }
                .keyboardShortcut(.upArrow, modifiers: [.command, .shift])
            }
        }
    }
}

struct DocumentWindowConfigurator: NSViewRepresentable {
    let fileURL: URL?

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window, let fileURL else { return }
            let autosaveName = "doc-\(fileURL.path.hashValue)"
            if !window.setFrameAutosaveName(autosaveName) {
                window.setFrameUsingName(autosaveName)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show(themeManager: ThemeManager, editorManager: EditorManager) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let settingsView = SettingsView()
            .environmentObject(themeManager)
            .environmentObject(editorManager)

        let hostingView = NSHostingView(rootView: settingsView)
        hostingView.frame = NSRect(x: 0, y: 0, width: 600, height: 600)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "markdownViewr Settings"
        window.contentView = hostingView
        window.minSize = NSSize(width: 380, height: 350)
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)

        self.window = window
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
