//
//  PaneDividerView.swift
//  Notes
//
//  Created by Nick Rizk on 3/16/26.
//

import AppKit

/// A thin draggable divider between panes
class PaneDividerView: NSView {
    let orientation: SplitOrientation
    var onDrag: ((CGFloat) -> Void)?

    private var lastDragLocation: CGFloat = 0

    init(orientation: SplitOrientation) {
        self.orientation = orientation
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.separatorColor.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func resetCursorRects() {
        discardCursorRects()
        switch orientation {
        case .vertical:
            addCursorRect(bounds, cursor: .resizeLeftRight)
        case .horizontal:
            addCursorRect(bounds, cursor: .resizeUpDown)
        }
    }

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
}
