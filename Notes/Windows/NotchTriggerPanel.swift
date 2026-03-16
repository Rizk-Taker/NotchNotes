//
//  NotchTriggerPanel.swift
//  Notes
//
//  Created by Nick Rizk on 3/16/26.
//

import AppKit

/// A floating panel that extends the notch downward with a black region
/// containing white "create" text — mimicking the notch expanding.
class NotchTriggerPanel: NSPanel {

    private static let notchWidth: CGFloat = 200
    private static let extensionHeight: CGFloat = 30
    private static let cornerRadius: CGFloat = 14

    init() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let safeTop = screen.safeAreaInsets.top
        let notchHeight = max(safeTop, 32)

        let panelWidth = Self.notchWidth
        let panelHeight = notchHeight + Self.extensionHeight

        let origin = NSPoint(
            x: screen.frame.midX - panelWidth / 2,
            y: screen.frame.maxY - panelHeight
        )

        super.init(
            contentRect: NSRect(origin: origin, size: NSSize(width: panelWidth, height: panelHeight)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        level = .screenSaver
        hasShadow = false
        ignoresMouseEvents = true
        isMovableByWindowBackground = false
        collectionBehavior = [.canJoinAllSpaces, .stationary]

        setupContent(notchHeight: notchHeight)
        alphaValue = 0
    }

    private func setupContent(notchHeight: CGFloat) {
        let size = contentRect(forFrameRect: frame).size
        let container = NotchShapeView(
            frame: NSRect(origin: .zero, size: size),
            cornerRadius: Self.cornerRadius
        )

        // White text positioned in the extension area (bottom portion of the panel)
        let label = NSTextField(labelWithString: "press enter to create")
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = NSColor.white.withAlphaComponent(0.9)
        label.alignment = .center
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false

        container.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.heightAnchor.constraint(equalToConstant: Self.extensionHeight),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        contentView = container
    }

    func showAnimated() {
        orderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1
        }
    }

    func hideAnimated() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.08
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
        })
    }
}

// MARK: - Custom view that draws the black notch-extension shape

private class NotchShapeView: NSView {
    private let cornerRadius: CGFloat

    init(frame: NSRect, cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
        super.init(frame: frame)
        wantsLayer = false  // Use draw(_:) for reliable rendering
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds
        let cr = cornerRadius

        // Black shape: full rectangle with only bottom-left and bottom-right corners rounded
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX, y: rect.maxY))                   // top-left (square)
        path.line(to: NSPoint(x: rect.maxX, y: rect.maxY))                   // top-right (square)
        path.line(to: NSPoint(x: rect.maxX, y: rect.minY + cr))              // right side down
        path.appendArc(withCenter: NSPoint(x: rect.maxX - cr, y: rect.minY + cr),  // bottom-right
                       radius: cr, startAngle: 0, endAngle: 270, clockwise: true)
        path.line(to: NSPoint(x: rect.minX + cr, y: rect.minY))              // bottom edge
        path.appendArc(withCenter: NSPoint(x: rect.minX + cr, y: rect.minY + cr),  // bottom-left
                       radius: cr, startAngle: 270, endAngle: 180, clockwise: true)
        path.close()

        NSColor.black.setFill()
        path.fill()
    }
}
