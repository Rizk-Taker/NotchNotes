//
//  PaneDividerView.swift
//  Notes
//
//  Created by Nick Rizk on 3/16/26.
//

import AppKit

/// A thin draggable divider between panes with a wide invisible grab zone
class PaneDividerView: NSView {
    let orientation: SplitOrientation
    var onDrag: ((CGFloat) -> Void)?
    var onDoubleClick: (() -> Void)?

    private var lastDragLocation: CGFloat = 0
    private var trackingArea: NSTrackingArea?
    private var isHovered = false

    /// Visual thickness of the divider line
    static let visualThickness: CGFloat = 3
    /// Invisible grab zone extends this far on each side of the visual divider
    private static let grabPadding: CGFloat = 4.5  // total hit zone = 3 + 4.5*2 = 12

    init(orientation: SplitOrientation) {
        self.orientation = orientation
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.separatorColor.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Hit Testing (expanded grab zone)

    override func hitTest(_ point: NSPoint) -> NSView? {
        let expandedBounds: NSRect
        switch orientation {
        case .vertical:
            expandedBounds = bounds.insetBy(dx: -Self.grabPadding, dy: 0)
        case .horizontal:
            expandedBounds = bounds.insetBy(dx: 0, dy: -Self.grabPadding)
        }
        let localPoint = convert(point, from: superview)
        if expandedBounds.contains(localPoint) {
            return self
        }
        return nil
    }

    // MARK: - Tracking Area (hover highlight)

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let expandedRect: NSRect
        switch orientation {
        case .vertical:
            expandedRect = bounds.insetBy(dx: -Self.grabPadding, dy: 0)
        case .horizontal:
            expandedRect = bounds.insetBy(dx: 0, dy: -Self.grabPadding)
        }
        trackingArea = NSTrackingArea(
            rect: expandedRect,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.animator().layer?.backgroundColor = NSColor.selectedControlColor.cgColor
        }
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            self.animator().layer?.backgroundColor = NSColor.separatorColor.cgColor
        }
    }

    // MARK: - Cursor

    override func resetCursorRects() {
        discardCursorRects()
        let expandedRect: NSRect
        switch orientation {
        case .vertical:
            expandedRect = bounds.insetBy(dx: -Self.grabPadding, dy: 0)
            addCursorRect(expandedRect, cursor: .resizeLeftRight)
        case .horizontal:
            expandedRect = bounds.insetBy(dx: 0, dy: -Self.grabPadding)
            addCursorRect(expandedRect, cursor: .resizeUpDown)
        }
    }

    // MARK: - Mouse Drag

    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        switch orientation {
        case .vertical: lastDragLocation = location.x
        case .horizontal: lastDragLocation = location.y
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        let delta: CGFloat
        switch orientation {
        case .vertical:
            delta = location.x - lastDragLocation
        case .horizontal:
            delta = location.y - lastDragLocation
        }
        onDrag?(delta)
    }

    // MARK: - Double Click to Equalize

    override func mouseUp(with event: NSEvent) {
        if event.clickCount == 2 {
            onDoubleClick?()
        }
    }
}
