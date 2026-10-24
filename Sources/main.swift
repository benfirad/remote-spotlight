import SwiftUI
import AppKit
import Carbon

// Global Carbon HotKey Handler
private var hotKeyRef: EventHotKeyRef?

// Custom NSPanel that guarantees it can become Key window and receive typing
final class SpotlightPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    override var acceptsFirstResponder: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var spotlightPanel: SpotlightPanel?
    private let engine = RMOSSearchEngine()

    public weak var currentSearchField: CustomNSTextField?

    private var openTimestamp: Date = Date.distantPast
    private var isOpening: Bool = false
    private var outsideClickMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBarItem()
        setupSpotlightPanel()
        registerGlobalHotKey()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSpotlight()
        return true
    }

    private func setupStatusBarItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            let image = NSImage(systemSymbolName: "sparkle.magnifyingglass", accessibilityDescription: "RM-OS Spotlight Arama")
            image?.isTemplate = true
            button.image = image
            button.target = self
            button.action = #selector(statusBarButtonClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "RM-OS Spotlight (⌥ + Boşluk veya tıkla)"
        }
        self.statusItem = item
    }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "RM-OS Spotlight'ı Aç (⌥+Space)", action: #selector(toggleSpotlight), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Önbelleği Güncelle (update-cache)", action: #selector(updateCache), keyEquivalent: "u"))
            menu.addItem(NSMenuItem(title: "RM-OS Durumu (status)", action: #selector(checkStatus), keyEquivalent: "s"))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Çıkış", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            statusItem?.menu = menu
            statusItem?.button?.performClick(nil)
            statusItem?.menu = nil
            return
        }

        // Debounce toggle clicks to prevent rapid open-close cycles
        guard let panel = spotlightPanel else { return }
        if panel.isVisible {
            if Date().timeIntervalSince(openTimestamp) > 0.35 {
                closeSpotlight()
            }
        } else {
            openSpotlight()
        }
    }

    @objc private func updateCache() {
        DispatchQueue.global(qos: .userInitiated).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: AppConfig.shared.cliToolPath)
            p.arguments = ["update-cache"]
            try? p.run()
            p.waitUntilExit()
            DispatchQueue.main.async {
                self.showNotification(title: "Spotlight Önbellek", message: "FTS5 arama önbelleği başarıyla güncellendi.")
            }
        }
    }

    @objc private func checkStatus() {
        DispatchQueue.global(qos: .userInitiated).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: AppConfig.shared.cliToolPath)
            p.arguments = ["status"]
            let pipe = Pipe()
            p.standardOutput = pipe
            try? p.run()
            p.waitUntilExit()
            let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                self.showNotification(title: "Uzak Düğüm Durumu", message: out.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
    }

    private func setupSpotlightPanel() {
        // Window dimension matching exact SwiftUI layout (780 x 490)
        let panel = SpotlightPanel(
            contentRect: NSRect(x: 0, y: 0, width: 780, height: 490),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.delegate = self
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true

        // Crucial: Must be false so the panel immediately accepts key window and typing without clicking
        panel.becomesKeyOnlyIfNeeded = false

        // Crucial: Must be false so mouse clicks on search results are never swallowed as window drags
        panel.isMovableByWindowBackground = false

        // Crucial for eliminating square corners: window must NOT be opaque
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false

        let spotlightView = SpotlightView(
            engine: engine,
            onSelect: { [weak self] item in
                self?.copyToClipboard(item.snippet.replacingOccurrences(of: "⟦", with: "").replacingOccurrences(of: "⟧", with: ""))
                self?.closeSpotlight()
            },
            onReadRemote: { [weak self] item in
                self?.readRemote(loc: item.loc.isEmpty ? item.source : item.loc)
                self?.closeSpotlight()
            },
            onCopyCommand: { [weak self] item in
                let q = self?.engine.queryText ?? ""
                self?.copyToClipboard("rmos-remote search \"\(q)\"")
                self?.showNotification(title: "Kopyalandı", message: "rmos-remote search komutu panoya alındı.")
            },
            onLocateInFinder: { [weak self] item, openFile in
                guard let self = self else { return }
                self.engine.isOpeningFile = true
                self.engine.openingStatusText = openFile ? "Dosya açılıyor..." : "Finder'da aranıyor..."
                FileLocator.shared.locateInFinder(
                    source: item.source,
                    loc: item.loc,
                    openFile: openFile,
                    onProgress: { [weak self] msg in
                        DispatchQueue.main.async {
                            self?.engine.openingStatusText = msg
                        }
                    }
                ) { [weak self] success, result in
                    DispatchQueue.main.async {
                        self?.engine.isOpeningFile = false
                        self?.engine.openingStatusText = ""
                        if success {
                            self?.closeSpotlight()
                        } else {
                            NSSound.beep()
                            self?.engine.statusText = "Hata: \(result)"
                            self?.showNotification(title: "Dosya Açılamadı", message: result)
                        }
                    }
                }
            },
            onOpenFinderSearch: { [weak self] item in
                guard let self = self else { return }
                self.engine.isOpeningFile = true
                self.engine.openingStatusText = "FinderSearch açılıyor..."
                FileLocator.shared.locateAndOpen(
                    source: item.source,
                    loc: item.loc,
                    mode: .openInFinderSearch,
                    onProgress: { [weak self] msg in
                        DispatchQueue.main.async {
                            self?.engine.openingStatusText = msg
                        }
                    }
                ) { [weak self] success, result in
                    DispatchQueue.main.async {
                        self?.engine.isOpeningFile = false
                        self?.engine.openingStatusText = ""
                        if success {
                            self?.closeSpotlight()
                        } else {
                            NSSound.beep()
                            self?.engine.statusText = "Hata: \(result)"
                            self?.showNotification(title: "FinderSearch Açılamadı", message: result)
                        }
                    }
                }
            },
            onClose: { [weak self] in
                self?.closeSpotlight()
            }
        )

        panel.contentViewController = NSHostingController(rootView: spotlightView)
        self.spotlightPanel = panel
    }

    func windowDidResignKey(_ notification: Notification) {
        if isOpening || Date().timeIntervalSince(openTimestamp) < 0.35 { return }
        closeSpotlight()
    }

    @objc public func toggleSpotlight() {
        guard let panel = spotlightPanel else { return }
        if panel.isVisible {
            if Date().timeIntervalSince(openTimestamp) > 0.35 {
                closeSpotlight()
            }
        } else {
            openSpotlight()
        }
    }

    public func openSpotlight() {
        guard let panel = spotlightPanel else { return }

        self.isOpening = true
        self.openTimestamp = Date()

        // Reset query and search results cleanly
        self.engine.queryText = ""
        self.engine.selectedIndex = 0
        self.engine.results = []
        self.engine.statusText = "Aramak için yazın..."
        self.engine.checkDatabaseFreshness()

        // Center on active screen
        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            let x = screenRect.midX - (780 / 2)
            let y = screenRect.midY - (490 / 2) + 100
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        panel.invalidateShadow()

        startOutsideClickMonitor()

        // Focus search text field immediately and repeat on micro-delays to guarantee immediate keyboard capture
        for delay in [0.0, 0.02, 0.05, 0.10, 0.20] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.ensureSearchFieldFocus()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) { [weak self] in
            self?.isOpening = false
        }
    }

    private func ensureSearchFieldFocus() {
        guard let panel = spotlightPanel, panel.isVisible else { return }
        panel.makeKeyAndOrderFront(nil)

        let targetField = currentSearchField ?? (panel.contentView.flatMap { findSearchField(in: $0) })
        if let field = targetField {
            currentSearchField = field
            panel.makeFirstResponder(field)
            field.selectText(nil)
            if let editor = field.currentEditor() {
                editor.selectedRange = NSRange(location: field.stringValue.count, length: 0)
            }
        }
    }

    private func findSearchField(in view: NSView) -> CustomNSTextField? {
        if let tf = view as? CustomNSTextField { return tf }
        for sub in view.subviews {
            if let found = findSearchField(in: sub) { return found }
        }
        return nil
    }

    private func startOutsideClickMonitor() {
        stopOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, let panel = self.spotlightPanel, panel.isVisible else { return }
            if self.isOpening || Date().timeIntervalSince(self.openTimestamp) < 0.35 { return }
            let clickLoc = NSEvent.mouseLocation
            if !panel.frame.contains(clickLoc) {
                self.closeSpotlight()
            }
        }
    }

    private func stopOutsideClickMonitor() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }

    public func closeSpotlight() {
        stopOutsideClickMonitor()
        spotlightPanel?.orderOut(nil)
    }

    private func copyToClipboard(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    private func readRemote(loc: String) {
        let cleanLoc = loc.components(separatedBy: "#").first ?? loc
        let rel = cleanLoc.replacingOccurrences(of: "RM-OS/", with: "")
        copyToClipboard("rmos-remote read \"\(rel)\"")
        showNotification(title: "Okuma Komutu Kopyalandı", message: "Terminalde çalıştırmak için: rmos-remote read \"\(rel)\"")
    }

    private func showNotification(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Tamam")
        alert.runModal()
    }

    // Global HotKey (⌥ + Space) via Carbon
    private func registerGlobalHotKey() {
        var gMyHotKeyID = EventHotKeyID()
        gMyHotKeyID.signature = OSType(0x524D4F53) // 'RMOS'
        gMyHotKeyID.id = 1

        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = OSType(kEventHotKeyPressed)

        InstallEventHandler(GetApplicationEventTarget(), { (handler, event, userData) -> OSStatus in
            DispatchQueue.main.async {
                if let delegate = NSApp.delegate as? AppDelegate {
                    delegate.toggleSpotlight()
                }
            }
            return noErr
        }, 1, &eventType, nil, nil)

        // kVK_Space = 0x31 (49), optionKey = 0x0800
        let status = RegisterEventHotKey(
            UInt32(kVK_Space),
            UInt32(optionKey),
            gMyHotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status == noErr {
            print("RMOS Spotlight: Global Hotkey (⌥+Space) başarıyla kaydedildi.")
        } else {
            print("RMOS Spotlight: Global Hotkey kaydedilemedi, status: \(status)")
        }
    }
}

// App Entry
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
