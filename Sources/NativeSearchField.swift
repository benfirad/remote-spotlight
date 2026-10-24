import SwiftUI
import AppKit

public final class CustomNSTextField: NSTextField {
    override public var acceptsFirstResponder: Bool { true }

    override public func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let w = window {
            w.initialFirstResponder = self
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.currentSearchField = self
            }
        }
    }

    public func focus() {
        guard let window = self.window else { return }
        window.makeKey()
        window.makeFirstResponder(self)
        self.selectText(nil)
        if let editor = self.currentEditor() {
            editor.selectedRange = NSRange(location: self.stringValue.count, length: 0)
        }
    }
}

public struct NativeSearchField: NSViewRepresentable {
    @Binding public var text: String
    public var placeholder: String = "Aramak için yazın (örn: pasaport, tie, fatura)..."
    public var onTextChange: (String) -> Void
    public var onArrowUp: () -> Void
    public var onArrowDown: () -> Void
    public var onEscape: () -> Void
    public var onReturn: () -> Void

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeNSView(context: Context) -> CustomNSTextField {
        let field = CustomNSTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.isEditable = true
        field.isSelectable = true
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.placeholderString = placeholder
        field.font = NSFont.monospacedSystemFont(ofSize: 16, weight: .medium)
        field.textColor = NSColor.labelColor
        field.delegate = context.coordinator
        field.stringValue = text
        context.coordinator.textField = field

        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.currentSearchField = field
        }

        return field
    }

    public func updateNSView(_ nsView: CustomNSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    public final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NativeSearchField
        weak var textField: CustomNSTextField?

        init(_ parent: NativeSearchField) {
            self.parent = parent
        }

        public func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? CustomNSTextField else { return }
            var val = field.stringValue
            let configuredPrefix = AppConfig.shared.searchPrefix.lowercased() + " "
            if val.lowercased().hasPrefix(configuredPrefix) {
                val = String(val.dropFirst(configuredPrefix.count))
                field.stringValue = val
            } else if val.lowercased().hasPrefix("rmos-remote search ") {
                val = String(val.dropFirst("rmos-remote search ".count))
                field.stringValue = val
            }
            parent.text = val
            parent.onTextChange(val)
        }

        public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.moveUp(_:)) {
                parent.onArrowUp()
                return true
            } else if commandSelector == #selector(NSResponder.moveDown(_:)) {
                parent.onArrowDown()
                return true
            } else if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onEscape()
                return true
            } else if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onReturn()
                return true
            }
            return false
        }
    }
}
