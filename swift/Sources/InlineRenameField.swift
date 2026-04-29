import AppKit
import SwiftUI

/// AppKit-backed inline rename field. Used for the recording-title edit
/// affordance in the detail view and the sidebar list. SwiftUI's TextField
/// doesn't reliably auto-focus or auto-select on appear — neither
/// `@FocusState` nor a delayed `NSApp.sendAction(#selector(NSText.selectAll))`
/// hits consistently because the TextField might not yet own the field
/// editor when the action fires. Wrapping NSTextField directly lets us
/// grab first-responder and select-all in one synchronous step from the
/// view's lifecycle.
struct InlineRenameField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let font: NSFont
    let onSubmit: () -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit, onCancel: onCancel)
    }

    func makeNSView(context: Context) -> NSTextField {
        let tf = NSTextField()
        tf.placeholderString = placeholder
        tf.isBordered = false
        tf.drawsBackground = false
        tf.focusRingType = .none
        tf.font = font
        tf.stringValue = text
        tf.delegate = context.coordinator
        tf.target = context.coordinator
        tf.action = #selector(Coordinator.commit(_:))
        tf.cell?.usesSingleLineMode = true
        tf.cell?.wraps = false
        tf.cell?.isScrollable = true

        // Take focus + select all on the next runloop tick. The view has to
        // be in a window before makeFirstResponder will succeed.
        DispatchQueue.main.async {
            guard let window = tf.window else { return }
            window.makeFirstResponder(tf)
            (tf.currentEditor() as? NSTextView)?.selectAll(nil)
        }
        return tf
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        // Keep external @Binding changes in sync if they happen while the
        // user isn't actively editing. Avoid stomping the field while the
        // user is typing — that would jump the caret.
        if nsView.currentEditor() == nil, nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding var text: String
        let onSubmit: () -> Void
        let onCancel: () -> Void

        init(text: Binding<String>, onSubmit: @escaping () -> Void, onCancel: @escaping () -> Void) {
            self._text = text
            self.onSubmit = onSubmit
            self.onCancel = onCancel
        }

        func controlTextDidChange(_ notification: Notification) {
            if let tf = notification.object as? NSTextField {
                text = tf.stringValue
            }
        }

        @objc func commit(_ sender: NSTextField) {
            text = sender.stringValue
            onSubmit()
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                onCancel()
                return true
            }
            return false
        }
    }
}
