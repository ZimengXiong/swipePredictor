//
//  OverlayPanel.swift
//  SwipeTypeMac
//

import Cocoa
import SwiftUI

class OverlayPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 280),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        setup()
    }

    private func setup() {
        level = .floating
        isFloatingPanel = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        let hosting = NSHostingView(rootView: ContentView())
        hosting.frame = contentRect(forFrameRect: frame)
        hosting.autoresizingMask = [.width, .height]
        contentView = hosting

        // Position at bottom center
        positionAtBottomCenter()

        NotificationCenter.default.addObserver(
            self, selector: #selector(hide), name: .hideOverlay, object: nil
        )

        // Reposition when screen changes
        NotificationCenter.default.addObserver(
            self, selector: #selector(screenDidChange), name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
    }

    private func positionAtBottomCenter() {
        if let screen = NSScreen.main {
            let x = screen.visibleFrame.midX - frame.width / 2
            let y = screen.visibleFrame.minY + 60
            setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    @objc private func screenDidChange() {
        positionAtBottomCenter()
    }

    func showOverlay() {
        positionNearCursor()
        orderFrontRegardless()
    }

    private func positionNearCursor() {
        let mousePos = NSEvent.mouseLocation

        // Position overlay below and slightly to the right of mouse
        let x = mousePos.x + 10
        let y = mousePos.y - frame.height - 10

        // Ensure it stays on screen
        if let screen = NSScreen.main {
            let clampedX = min(max(x, screen.visibleFrame.minX), screen.visibleFrame.maxX - frame.width)
            let clampedY = min(max(y, screen.visibleFrame.minY), screen.visibleFrame.maxY - frame.height)
            setFrameOrigin(NSPoint(x: clampedX, y: clampedY))
        } else {
            positionAtBottomCenter()
        }
    }

    @objc func hide() {
        orderOut(nil)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension Notification.Name {
    static let hideOverlay = Notification.Name("hideOverlay")
}
