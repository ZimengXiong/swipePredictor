//
//  TextInsertionService.swift
//  SwipeTypeMac
//
//  Handles inserting text into the active application
//

import Cocoa

class TextInsertionService {
    static let shared = TextInsertionService()

    private init() {}

    /// Insert text into the currently focused text field using clipboard + Cmd+V
    func insertText(_ text: String) {
        let pasteboard = NSPasteboard.general

        // Save current clipboard
        let savedContents = pasteboard.pasteboardItems?.compactMap { item -> [(NSPasteboard.PasteboardType, Data)]? in
            item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            }
        }.flatMap { $0 } ?? []

        // Set clipboard to our text
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Small delay then paste
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.sendPaste()

            // Restore clipboard after paste completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if !savedContents.isEmpty {
                    pasteboard.clearContents()
                    for (type, data) in savedContents {
                        pasteboard.setData(data, forType: type)
                    }
                }
            }
        }
    }

    // MARK: - Key Events

    private func sendPaste() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Cmd down
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
        // V down
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        // V up
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        // Cmd up
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)

        cmdDown?.flags = .maskCommand
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand

        cmdDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
    }
}
