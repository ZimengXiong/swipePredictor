//
//  ContentView.swift
//  SwipeTypeMac
//

import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject private var appState = AppState.shared

    var body: some View {
        VStack(spacing: 8) {
            // Input
            Text(appState.currentInput.isEmpty ? " " : appState.currentInput)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(appState.isWordCommitted ? Color.green.opacity(0.25) : Color.black.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )

            // Predictions
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(appState.predictions.prefix(5).enumerated()), id: \.element.id) { index, pred in
                    HStack(spacing: 8) {
                        Text("\(index + 1)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(index == 0 ? .white : .secondary)
                            .frame(width: 18, height: 18)
                            .background(index == 0 ? Color.accentColor : Color.white.opacity(0.15))
                            .clipShape(Circle())

                        Text(pred.word)
                            .font(.system(size: 14, weight: index == 0 ? .semibold : .regular))
                            .foregroundColor(index == 0 ? Color(red: 0.4, green: 0.7, blue: 1.0) : .primary)

                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()

            // Keyboard
            KeyboardView(input: appState.currentInput)
                .frame(maxWidth: .infinity)

            // Hints
            Text("⇧⇥ toggle · ↵ or 1-5 select · ⎋ close")
                .font(.system(size: 9))
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)
        }
        .padding(12)
        .frame(width: 300, height: 280)
        .background(VisualEffectView())
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct KeyboardView: View {
    let input: String

    private let keyboardLayout: [(String, CGFloat, CGFloat)] = [
        ("Q", 0, 0), ("W", 1, 0), ("E", 2, 0), ("R", 3, 0), ("T", 4, 0),
        ("Y", 5, 0), ("U", 6, 0), ("I", 7, 0), ("O", 8, 0), ("P", 9, 0),
        ("A", 0.5, 1), ("S", 1.5, 1), ("D", 2.5, 1), ("F", 3.5, 1), ("G", 4.5, 1),
        ("H", 5.5, 1), ("J", 6.5, 1), ("K", 7.5, 1), ("L", 8.5, 1),
        ("Z", 1, 2), ("X", 2, 2), ("C", 3, 2), ("V", 4, 2), ("B", 5, 2),
        ("N", 6, 2), ("M", 7, 2)
    ]

    private var activeKeys: Set<Character> {
        Set(input.uppercased())
    }

    private var pathPoints: [(CGFloat, CGFloat)] {
        input.uppercased().compactMap { char in
            keyboardLayout.first { $0.0 == String(char) }.map { ($0.1, $0.2) }
        }
    }

    var body: some View {
        Canvas { context, size in
            let keyW: CGFloat = 26
            let keyH: CGFloat = 22
            let gap: CGFloat = 2

            func pos(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
                CGPoint(x: x * (keyW + gap) + keyW / 2 + 4, y: y * (keyH + gap) + keyH / 2 + 2)
            }

            // Draw path
            if pathPoints.count >= 2 {
                var path = Path()
                path.move(to: pos(pathPoints[0].0, pathPoints[0].1))
                for pt in pathPoints.dropFirst() {
                    path.addLine(to: pos(pt.0, pt.1))
                }
                context.stroke(path, with: .color(.accentColor.opacity(0.5)), lineWidth: 2)
            }

            // Draw keys
            for (key, x, y) in keyboardLayout {
                let p = pos(x, y)
                let rect = CGRect(x: p.x - keyW/2, y: p.y - keyH/2, width: keyW, height: keyH)
                let isActive = activeKeys.contains(Character(key))

                context.fill(RoundedRectangle(cornerRadius: 4).path(in: rect),
                           with: .color(isActive ? .accentColor.opacity(0.35) : Color.white.opacity(0.08)))
                context.stroke(RoundedRectangle(cornerRadius: 4).path(in: rect),
                             with: .color(isActive ? .accentColor : .white.opacity(0.2)), lineWidth: 0.5)
                context.draw(Text(key).font(.system(size: 10, weight: .medium))
                           .foregroundColor(isActive ? .accentColor : .primary), at: p)
            }
        }
        .frame(height: 72)
    }
}

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = true
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
