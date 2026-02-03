//
//  AppDelegate.swift
//  SwipeTypeMac
//

import Cocoa
import Carbon.HIToolbox

private var overlayIsVisible = false

class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayPanel: OverlayPanel?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Load dictionary through AppState (handles errors and auto-download)
        Task { @MainActor in
            AppState.shared.loadDictionary()
        }

        setupStatusItem()
        setupGlobalHotkey()
        overlayPanel = OverlayPanel()
    }

    func applicationWillTerminate(_ notification: Notification) {
        removeEventTap()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "SwipeType")

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Toggle Overlay (⇧⇥)", action: #selector(toggleOverlay), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let statusItem = NSMenuItem(title: "Status: Loading...", action: nil, keyEquivalent: "")
        statusItem.tag = 100
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        self.statusItem?.menu = menu

        // Update status periodically
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateStatusMenuItem()
        }
    }

    private func updateStatusMenuItem() {
        guard let menu = statusItem?.menu,
              let item = menu.item(withTag: 100) else { return }

        Task { @MainActor in
            let state = AppState.shared
            if state.isDictionaryLoaded {
                item.title = "✓ \(state.dictionaryWordCount) words loaded"
            } else {
                item.title = "✗ Dictionary not loaded"
            }
        }
    }

    @objc private func toggleOverlay() {
        Task { @MainActor in
            AppState.shared.toggleOverlay()
            overlayIsVisible = AppState.shared.isOverlayVisible
            if overlayIsVisible {
                overlayPanel?.showOverlay()
            } else {
                overlayPanel?.hide()
            }
        }
    }

    private func setupGlobalHotkey() {
        guard PermissionManager.shared.checkAccessibilityPermission() else {
            PermissionManager.shared.requestAccessibilityPermission()
            // Monitor for permission grant and retry
            PermissionManager.shared.startMonitoringPermission { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.setupGlobalHotkey()
                    }
                }
            }
            return
        }

        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon -> Unmanaged<CGEvent>? in
                AppDelegate.handleEvent(type: type, event: event, refcon: refcon)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    private func removeEventTap() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes) }
    }

    private static func handleEvent(type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
        guard type == .keyDown || type == .keyUp else { return Unmanaged.passRetained(event) }

        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        // Shift+Tab toggle
        if keyCode == kVK_Tab && flags.contains(.maskShift) {
            if type == .keyDown {
                DispatchQueue.main.async {
                    guard let refcon else { return }
                    Unmanaged<AppDelegate>.fromOpaque(refcon).takeUnretainedValue().toggleOverlay()
                }
            }
            return nil
        }

        guard type == .keyDown, overlayIsVisible else { return Unmanaged.passRetained(event) }

        // Let modifier key combinations (Cmd+key, Ctrl+key, Option+key) pass through
        // These are likely shortcuts (including our own Cmd+V for paste)
        let hasModifier = flags.contains(.maskCommand) || flags.contains(.maskControl) || flags.contains(.maskAlternate)
        if hasModifier {
            return Unmanaged.passRetained(event)
        }

        return handleKey(keyCode, flags: flags) ? nil : Unmanaged.passRetained(event)
    }

    // Keys that should pass through even when overlay is visible
    private static let passthroughKeys: Set<Int> = [
        kVK_Command, kVK_Shift, kVK_Option, kVK_Control,
        kVK_RightCommand, kVK_RightShift, kVK_RightOption, kVK_RightControl,
        kVK_CapsLock, kVK_Function,
        kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6,
        kVK_F7, kVK_F8, kVK_F9, kVK_F10, kVK_F11, kVK_F12,
        kVK_VolumeUp, kVK_VolumeDown, kVK_Mute
    ]

    private static func handleKey(_ keyCode: Int, flags: CGEventFlags) -> Bool {
        // Let modifier and function keys pass through
        if passthroughKeys.contains(keyCode) {
            return false
        }

        // Consume all other keys when overlay is visible to prevent leaking
        DispatchQueue.main.async {
            let state = AppState.shared

            switch keyCode {
            case kVK_Escape:
                state.hideOverlay()
                overlayIsVisible = false
                NotificationCenter.default.post(name: .hideOverlay, object: nil)

            case kVK_Delete:
                state.deleteCharacter()

            case kVK_Return:
                if let word = state.selectPrediction(at: 0) {
                    TextInsertionService.shared.insertText(word + " ")
                }

            case kVK_Space:
                // Consume space but do nothing - prevents leaking to active app
                break

            default:
                if keyCode >= kVK_ANSI_1 && keyCode <= kVK_ANSI_5 {
                    if let word = state.selectPrediction(at: keyCode - kVK_ANSI_1) {
                        TextInsertionService.shared.insertText(word + " ")
                    }
                } else if let char = keyCodeToChar(keyCode) {
                    if let autoWord = state.addCharacter(char) {
                        TextInsertionService.shared.insertText(autoWord + " ")
                    }
                }
            }
        }

        // Consume all non-passthrough keys to prevent leaking to active app
        return true
    }

    private static func keyCodeToChar(_ keyCode: Int) -> Character? {
        [kVK_ANSI_A: "a", kVK_ANSI_B: "b", kVK_ANSI_C: "c", kVK_ANSI_D: "d",
         kVK_ANSI_E: "e", kVK_ANSI_F: "f", kVK_ANSI_G: "g", kVK_ANSI_H: "h",
         kVK_ANSI_I: "i", kVK_ANSI_J: "j", kVK_ANSI_K: "k", kVK_ANSI_L: "l",
         kVK_ANSI_M: "m", kVK_ANSI_N: "n", kVK_ANSI_O: "o", kVK_ANSI_P: "p",
         kVK_ANSI_Q: "q", kVK_ANSI_R: "r", kVK_ANSI_S: "s", kVK_ANSI_T: "t",
         kVK_ANSI_U: "u", kVK_ANSI_V: "v", kVK_ANSI_W: "w", kVK_ANSI_X: "x",
         kVK_ANSI_Y: "y", kVK_ANSI_Z: "z"][keyCode]
    }
}
