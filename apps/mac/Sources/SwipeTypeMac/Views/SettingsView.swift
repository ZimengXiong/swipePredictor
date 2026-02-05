//
//  SettingsView.swift
//  SwipeTypeMac
//

import SwiftUI

struct SettingsView: View {
    @AppStorage(AppSettings.Keys.hotkeyPreset) private var hotkeyPresetRaw = AppSettings.Defaults.hotkeyPreset.rawValue
    @AppStorage(AppSettings.Keys.showMenuBarItem) private var showMenuBarItem = AppSettings.Defaults.showMenuBarItem

    @AppStorage(AppSettings.Keys.customToggleHotkeyKeyCode) private var customToggleHotkeyKeyCode = AppSettings.Defaults.customToggleHotkeyKeyCode
    @AppStorage(AppSettings.Keys.customToggleHotkeyModifiers) private var customToggleHotkeyModifiers = AppSettings.Defaults.customToggleHotkeyModifiers

    @AppStorage(AppSettings.Keys.autoCommitAfterPause) private var autoCommitAfterPause = AppSettings.Defaults.autoCommitAfterPause
    @AppStorage(AppSettings.Keys.debounceDelaySeconds) private var debounceDelaySeconds = AppSettings.Defaults.debounceDelaySeconds
    @AppStorage(AppSettings.Keys.requirePauseBeforeCommit) private var requirePauseBeforeCommit = AppSettings.Defaults.requirePauseBeforeCommit
    @AppStorage(AppSettings.Keys.insertTrailingSpace) private var insertTrailingSpace = AppSettings.Defaults.insertTrailingSpace
    @AppStorage(AppSettings.Keys.overlayBackgroundOpacity) private var overlayBackgroundOpacity = AppSettings.Defaults.overlayBackgroundOpacity
    @AppStorage(AppSettings.Keys.useTransparency) private var useTransparency = AppSettings.Defaults.useTransparency
    @AppStorage(AppSettings.Keys.playSwipeAnimation) private var playSwipeAnimation = AppSettings.Defaults.playSwipeAnimation

    @State private var isShowingResetConfirmation = false

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (version, build) {
        case let (v?, b?):
            return "Version \(v) (\(b))"
        case let (v?, nil):
            return "Version \(v)"
        case let (nil, b?):
            return "Build \(b)"
        default:
            return ""
        }
    }

    private var hotkeyPreset: AppSettings.ToggleHotkeyPreset {
        AppSettings.ToggleHotkeyPreset(rawValue: hotkeyPresetRaw) ?? AppSettings.Defaults.hotkeyPreset
    }

    private var isCustomHotkeyValid: Bool {
        customToggleHotkeyModifiers != 0
    }

    private var isMenuBarRequired: Bool {
        switch hotkeyPreset {
        case .none:
            return true
        case .custom:
            return !isCustomHotkeyValid
        default:
            return false
        }
    }

    private func modifierBinding(_ bit: Int) -> Binding<Bool> {
        Binding(
            get: { (customToggleHotkeyModifiers & bit) != 0 },
            set: { isOn in
                if isOn {
                    customToggleHotkeyModifiers |= bit
                } else {
                    customToggleHotkeyModifiers &= ~bit
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Form {
                Section {
                    Picker("Toggle overlay", selection: $hotkeyPresetRaw) {
                        ForEach(AppSettings.ToggleHotkeyPreset.allCases) { preset in
                            Text(preset.displayName).tag(preset.rawValue)
                        }
                    }
                    .pickerStyle(.menu)

                    if hotkeyPreset == .none {
                        Text("Hotkey disabled. Use the menu bar icon to toggle the overlay.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if hotkeyPreset == .custom {
                        LabeledContent("Key") {
                            HStack {
                                Spacer()
                                Picker("Key", selection: $customToggleHotkeyKeyCode) {
                                    ForEach(AppSettings.customHotkeyKeyOptions) { option in
                                        Text(option.displayName).tag(option.keyCode)
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                            }
                        }

                        LabeledContent("Modifiers") {
                            HStack {
                                Spacer()
                                HStack(spacing: 4) {
                                    ModifierToggle(symbol: "⌃", name: "Control", isOn: modifierBinding(AppSettings.ModifierBits.control))
                                    ModifierToggle(symbol: "⌥", name: "Option", isOn: modifierBinding(AppSettings.ModifierBits.option))
                                    ModifierToggle(symbol: "⇧", name: "Shift", isOn: modifierBinding(AppSettings.ModifierBits.shift))
                                    ModifierToggle(symbol: "⌘", name: "Command", isOn: modifierBinding(AppSettings.ModifierBits.command))
                                }
                            }
                        }

                        LabeledContent("Preview") {
                            Text(AppSettings.hotkeyHintSymbol(keyCode: customToggleHotkeyKeyCode, modifierMask: customToggleHotkeyModifiers))
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.semibold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.primary.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }

                        if !isCustomHotkeyValid {
                            Text("Select at least one modifier.")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                } header: {
                    Label("Hotkey", systemImage: "keyboard")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Section {
                    Toggle("Show menu bar icon", isOn: $showMenuBarItem)
                        .disabled(isMenuBarRequired)

                    if isMenuBarRequired {
                        Text("Menu bar icon is required when no hotkey is configured.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("Menu Bar", systemImage: "menubar.rectangle")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Section {
                    VStack(alignment: .leading, spacing: 2) {
                        Toggle("Auto-commit after pause", isOn: $autoCommitAfterPause)
                        Text("Automatically inserts the top prediction when you start typing a new word.")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary.opacity(0.8))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Toggle("Require pause before Enter/1-5", isOn: $requirePauseBeforeCommit)
                        Text("Prevents accidental selection by requiring a short pause after finishing a swipe.")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary.opacity(0.8))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Toggle("Add space after committed word", isOn: $insertTrailingSpace)
                        Text("Appends a space character whenever a word is selected or auto-committed.")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary.opacity(0.8))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Toggle("Play swipe animation after pause", isOn: $playSwipeAnimation)
                        Text("Replays your swipe path on the overlay keyboard for visual feedback.")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary.opacity(0.8))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        LabeledContent("Pause duration") {
                            VStack(alignment: .trailing, spacing: 2) {
                                Slider(value: $debounceDelaySeconds, in: 0.15...1.2, step: 0.05)
                                    .frame(width: 180)
                                Text("\(debounceDelaySeconds, specifier: "%.2f")s")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text("How long to wait after you stop typing before committing or playing the animation.")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary.opacity(0.8))
                    }
                } header: {
                    Label("Typing", systemImage: "square.and.pencil")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Toggle("Use transparency", isOn: $useTransparency)
                            Text("Enables the native macOS blurred background effect.")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary.opacity(0.8))
                        }

                        HStack {
                            Text(useTransparency ? "Background dim" : "Background opacity")
                            Spacer()
                            Slider(value: $overlayBackgroundOpacity, in: 0.0...0.9, step: 0.05)
                                .frame(width: 160)
                            Text("\(Int(overlayBackgroundOpacity * 100))%")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 35, alignment: .trailing)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Appearance Preview")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                            
                            // The Actual Mock Overlay (Miniature)
                            VStack(spacing: 6) {
                                // Predictions
                                VStack(spacing: 3) {
                                    MockRow(text: "alpaca", primary: true)
                                    MockRow(text: "penguin", primary: false)
                                }
                                
                                // Stats
                                HStack {
                                    Rectangle().fill(.white.opacity(0.3)).frame(width: 45, height: 3)
                                    Spacer()
                                    Rectangle().fill(.white.opacity(0.3)).frame(width: 30, height: 3)
                                }
                                .padding(.horizontal, 6)
                                
                                // Keyboard mock
                                MockKeyboardView(input: "asdfghjklppokjhgfdsaxccsa")
                                    .frame(height: 80)
                                    .padding(.top, 4)
                                
                                // Footer
                                Capsule().fill(.white.opacity(0.2)).frame(width: 60, height: 3)
                            }
                            .padding(12)
                            .frame(width: 180)
                            .background(
                                ZStack {
                                    if useTransparency {
                                        // Simple representation of transparency over form background
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.gray.opacity(0.12))
                                        
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(.black.opacity(overlayBackgroundOpacity))
                                    } else {
                                        // Fully opaque background mock
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(white: 0.25 * (1.0 - overlayBackgroundOpacity / 0.9)))
                                    }
                                    
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 0.5)
                                }
                            )
                            .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Label("Overlay", systemImage: "macwindow")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Section {
                    Button {
                        PermissionManager.shared.requestAccessibilityPermission()
                    } label: {
                        Label("Request Accessibility Permission", systemImage: "hand.raised.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                } header: {
                    Label("Permissions", systemImage: "lock.shield")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 16) {
                            Image(nsImage: NSApp.applicationIconImage)
                                .resizable()
                                .frame(width: 48, height: 48)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("SwipeType")
                                    .font(.headline)
                                if !appVersionText.isEmpty {
                                    Text(appVersionText)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        Text("A fast, lightweight swipe typing engine for macOS. Use swipe patterns to type words efficiently across any application.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineSpacing(2)
                        
                        Link(destination: URL(string: "https://github.com/ZimengXiong/swipeType")!) {
                            Label("View on GitHub", systemImage: "link")
                                .font(.caption.bold())
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Label("About", systemImage: "info.circle")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
            }
            .formStyle(.grouped)

            Button(role: .destructive) {
                isShowingResetConfirmation = true
            } label: {
                Text("Reset to Defaults")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .controlSize(.small)
            .clipShape(Capsule())
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
        .frame(width: 520)
        .fixedSize(horizontal: true, vertical: true)
        .onChange(of: hotkeyPresetRaw) { _ in
            if isMenuBarRequired {
                showMenuBarItem = true
            }
        }
        .onChange(of: customToggleHotkeyModifiers) { _ in
            if isMenuBarRequired {
                showMenuBarItem = true
            }
        }
        .confirmationDialog(
            "Reset all settings?",
            isPresented: $isShowingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                AppSettings.resetToDefaults()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will restore default settings for hotkey, typing, and overlay.")
        }
    }
}

private struct MockKeyboardView: View {
    let input: String
    
    private let keyboardLayout: [(String, CGFloat, CGFloat)] = [
        ("Q", 0, 0), ("W", 1, 0), ("E", 2, 0), ("R", 3, 0), ("T", 4, 0),
        ("Y", 5, 0), ("U", 6, 0), ("I", 7, 0), ("O", 8, 0), ("P", 9, 0),
        ("A", 1, 1), ("S", 2, 1), ("D", 3, 1), ("F", 4, 1), ("G", 5, 1),
        ("H", 6, 1), ("J", 7, 1), ("K", 8, 1), ("L", 9, 1),
        ("Z", 1.5, 2), ("X", 2.5, 2), ("C", 3.5, 2), ("V", 4.5, 2), ("B", 5.5, 2),
        ("N", 6.5, 2), ("M", 7.5, 2)
    ]

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.periodic(from: .now, by: 1.0/60.0)) { timeline in
                Canvas { context, size in
                    let keySize: CGFloat = 13
                    let gap: CGFloat = 3
                    
                    let totalCols: CGFloat = 10
                    let keyboardWidth = totalCols * (keySize + gap) - gap
                    let leftPad = (size.width - keyboardWidth) / 2
                    let topPad: CGFloat = 2
                    
                    func center(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                        CGPoint(
                            x: x * (keySize + gap) + keySize/2 + leftPad,
                            y: y * (keySize + gap) + keySize/2 + topPad
                        )
                    }
                    
                    // Draw Keys
                    for (_, x, y) in keyboardLayout {
                        let p = center(x, y)
                        let rect = CGRect(x: p.x - keySize/2, y: p.y - keySize/2, width: keySize, height: keySize)
                        context.fill(RoundedRectangle(cornerRadius: 2).path(in: rect), with: .color(.white.opacity(0.12)))
                    }
                    
                    // Draw Animated Path
                    let rawPoints: [CGPoint] = input.uppercased().compactMap { char in
                        guard let entry = keyboardLayout.first(where: { $0.0 == String(char) }) else { return nil }
                        return center(entry.1, entry.2)
                    }
                    
                    // Apply pronounced stable jitter for the "sloppy" look
                    let points = rawPoints.enumerated().map { idx, pt in
                        var state = UInt64(idx) &* 0x12345678 ^ 0x87654321
                        let dx = (nextRandom(&state) - 0.5) * 4.0
                        let dy = (nextRandom(&state) - 0.5) * 4.0
                        return CGPoint(x: pt.x + dx, y: pt.y + dy)
                    }
                    
                    if points.count >= 2 {
                        let totalDuration: TimeInterval = 1.2 // Faster snappy animation
                        let elapsed = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: totalDuration)
                        let progress = elapsed / (totalDuration * 0.75) // allow for pause
                        
                        if progress < 1.0 {
                            let count = Int(Double(points.count - 1) * progress) + 1
                            let visiblePoints = Array(points.prefix(max(2, count)))
                            
                            let path = smoothPath(points: visiblePoints)
                            context.stroke(path, with: .color(Color.accentColor.opacity(0.7)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                            
                            if let last = visiblePoints.last {
                                context.fill(Path(ellipseIn: CGRect(x: last.x - 3, y: last.y - 3, width: 6, height: 6)), with: .color(Color.accentColor))
                            }
                        } else {
                            // Pause state: show full path
                            let path = smoothPath(points: points)
                            context.stroke(path, with: .color(Color.accentColor.opacity(0.7)), style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                            if let last = points.last {
                                context.fill(Path(ellipseIn: CGRect(x: last.x - 3, y: last.y - 3, width: 6, height: 6)), with: .color(Color.accentColor))
                            }
                        }
                    }
                }
            }
        }
    }

    private func smoothPath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        if points.count == 2 {
            path.addLine(to: points[1])
            return path
        }
        if points.count > 2 {
            let firstMid = CGPoint(x: (points[0].x + points[1].x) * 0.5, y: (points[0].y + points[1].y) * 0.5)
            path.addLine(to: firstMid)
            for i in 1..<(points.count - 1) {
                let curr = points[i]
                let next = points[i+1]
                let mid = CGPoint(x: (curr.x + next.x) * 0.5, y: (curr.y + next.y) * 0.5)
                path.addQuadCurve(to: mid, control: curr)
            }
        }
        if let last = points.last { path.addLine(to: last) }
        return path
    }

    private func nextRandom(_ state: inout UInt64) -> CGFloat {
        state = state &* 6364136223846793005 &+ 1
        let value = Double(state >> 33) / Double(1 << 31)
        return CGFloat(value)
    }
}

private struct MockRow: View {
    let text: String
    let primary: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(primary ? Color.accentColor : .white.opacity(0.3))
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 10, weight: primary ? .bold : .regular))
                .foregroundColor(primary ? .white : .white.opacity(0.8))
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.white.opacity(primary ? 0.15 : 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

private struct ModifierToggle: View {
    let symbol: String
    let name: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(symbol, isOn: $isOn)
            .toggleStyle(.button)
            .font(.system(.body, design: .rounded))
            .fontWeight(.medium)
            .frame(width: 32)
            .help(name)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}