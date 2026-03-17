//
//  DockPreviewOverlay.swift
//  Notes
//
//  Created by Nick Rizk on 3/16/26.
//

import AppKit

/// The four directional drop zones plus a "none" state (cursor in center)
enum DockZone: Equatable {
    case left, right, top, bottom, none
}

/// Custom NSView that draws iTerm2-style drop zone indicators on the target window.
/// When the user drags a window and the cursor enters another window, this overlay
/// appears showing directional zones. The active zone highlights to indicate where
/// the dragged window will dock.
class DockZoneOverlayView: NSView {

    /// Fraction of each dimension that counts as an edge zone
    static let edgeFraction: CGFloat = 0.25

    /// Currently highlighted zone
    var activeZone: DockZone = .none {
        didSet {
            if oldValue != activeZone {
                needsDisplay = true
            }
        }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let inset: CGFloat = 6
        let cornerRadius: CGFloat = 8
        let accentColor = NSColor.controlAccentColor

        // Draw a subtle full-window tint to indicate a valid dock target
        accentColor.withAlphaComponent(0.05).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: inset, dy: inset),
                     xRadius: cornerRadius, yRadius: cornerRadius).fill()

        guard activeZone != .none else { return }

        // Calculate and draw the highlighted zone rect
        let zoneRect = rectForZone(activeZone).insetBy(dx: inset, dy: inset)

        // Fill
        accentColor.withAlphaComponent(0.25).setFill()
        NSBezierPath(roundedRect: zoneRect,
                     xRadius: cornerRadius, yRadius: cornerRadius).fill()

        // Border
        accentColor.withAlphaComponent(0.5).setStroke()
        let strokePath = NSBezierPath(roundedRect: zoneRect.insetBy(dx: 1, dy: 1),
                                      xRadius: cornerRadius, yRadius: cornerRadius)
        strokePath.lineWidth = 2
        strokePath.stroke()
    }

    /// Returns the rect for a given zone within this view's bounds
    private func rectForZone(_ zone: DockZone) -> NSRect {
        let w = bounds.width
        let h = bounds.height
        let edgeW = w * Self.edgeFraction
        let edgeH = h * Self.edgeFraction

        switch zone {
        case .left:
            return NSRect(x: 0, y: 0, width: edgeW, height: h)
        case .right:
            return NSRect(x: w - edgeW, y: 0, width: edgeW, height: h)
        case .top:
            return NSRect(x: 0, y: h - edgeH, width: w, height: edgeH)
        case .bottom:
            return NSRect(x: 0, y: 0, width: w, height: edgeH)
        case .none:
            return .zero
        }
    }

    /// Determines which zone a point (in screen coordinates) falls in, given a
    /// window frame (also in screen coordinates). Returns `.none` if the point
    /// is in the center region (more than 25% from all edges).
    static func zoneForPoint(_ point: NSPoint, in frame: NSRect) -> DockZone {
        guard frame.contains(point) else { return .none }

        // Normalize to 0...1 within the frame
        let nx = (point.x - frame.minX) / frame.width
        let ny = (point.y - frame.minY) / frame.height

        // Distance from each edge (0 = at edge, 1 = opposite edge)
        let distLeft = nx
        let distRight = 1 - nx
        let distBottom = ny
        let distTop = 1 - ny

        let ef = edgeFraction
        let inLeft = distLeft < ef
        let inRight = distRight < ef
        let inBottom = distBottom < ef
        let inTop = distTop < ef

        // If not in any edge zone, cursor is in the center — no dock direction
        if !inLeft && !inRight && !inBottom && !inTop {
            return .none
        }

        // Closest edge wins (handles corner disambiguation)
        let distances: [(DockZone, CGFloat)] = [
            (.left, distLeft),
            (.right, distRight),
            (.top, distTop),
            (.bottom, distBottom),
        ]

        return distances.min(by: { $0.1 < $1.1 })?.0 ?? .none
    }
}
