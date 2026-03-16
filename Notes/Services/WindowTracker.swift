//
//  WindowTracker.swift
//  Notes
//
//  Created by Nick Rizk on 3/16/26.
//

import AppKit

/// Tracks all open note windows for docking detection and management
class WindowTracker {
    static let shared = WindowTracker()
    private init() {}

    /// All active note window controllers
    private(set) var controllers: [NoteWindowController] = []

    /// All note windows currently open
    var allNoteWindows: [NSWindow] {
        controllers.compactMap { $0.window }
    }

    // MARK: - Window Protocol

    /// Protocol that both standalone and split window controllers conform to
    func controller(for window: NSWindow) -> NoteWindowController? {
        return controllers.first { $0.window === window }
    }

    // MARK: - Create / Open

    func createNewNote() {
        let document = NoteDocument()
        let controller = NoteWindowController(document: document)
        register(controller)
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func openFile(url: URL) {
        // Check if already open
        if let existing = controllers.first(where: {
            $0.windowState.focusedDocument?.fileURL == url ||
            $0.windowState.rootNode.allLeaves.contains(where: { $0.document.fileURL == url })
        }) {
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }

        guard let document = NoteDocument.load(from: url) else { return }
        let controller = NoteWindowController(document: document)
        register(controller)
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Registration

    func register(_ controller: NoteWindowController) {
        controllers.append(controller)
    }

    func unregister(_ controller: NoteWindowController) {
        controllers.removeAll { $0 === controller }
    }

    // MARK: - Docking Queries

    /// Returns the closest note window (and its edge) to the given window frame, if within docking threshold
    func findDockTarget(for movingWindow: NSWindow) -> (controller: NoteWindowController, edge: DockEdge, leafID: UUID)? {
        let threshold: CGFloat = 20
        let movingFrame = movingWindow.frame

        for controller in controllers {
            guard let targetWindow = controller.window,
                  targetWindow !== movingWindow else { continue }

            let targetFrame = targetWindow.frame

            // Check each edge
            if let result = checkEdgeProximity(
                movingFrame: movingFrame,
                targetFrame: targetFrame,
                threshold: threshold,
                controller: controller
            ) {
                return result
            }
        }
        return nil
    }

    private func checkEdgeProximity(
        movingFrame: NSRect,
        targetFrame: NSRect,
        threshold: CGFloat,
        controller: NoteWindowController
    ) -> (controller: NoteWindowController, edge: DockEdge, leafID: UUID)? {
        // Must overlap vertically or horizontally to dock
        let verticalOverlap = movingFrame.minY < targetFrame.maxY && movingFrame.maxY > targetFrame.minY
        let horizontalOverlap = movingFrame.minX < targetFrame.maxX && movingFrame.maxX > targetFrame.minX

        guard let focusedID = controller.windowState.focusedLeafID
            ?? controller.windowState.rootNode.allLeaves.first?.id else { return nil }

        // Right edge of moving window near left edge of target
        if verticalOverlap && abs(movingFrame.maxX - targetFrame.minX) < threshold {
            return (controller, .left, focusedID)
        }
        // Left edge of moving window near right edge of target
        if verticalOverlap && abs(movingFrame.minX - targetFrame.maxX) < threshold {
            return (controller, .right, focusedID)
        }
        // Top edge of moving window near bottom edge of target (macOS coords: y increases up)
        if horizontalOverlap && abs(movingFrame.maxY - targetFrame.minY) < threshold {
            return (controller, .bottom, focusedID)
        }
        // Bottom edge of moving window near top edge of target
        if horizontalOverlap && abs(movingFrame.minY - targetFrame.maxY) < threshold {
            return (controller, .top, focusedID)
        }

        return nil
    }
}
