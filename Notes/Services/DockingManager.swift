//
//  DockingManager.swift
//  Notes
//
//  Created by Nick Rizk on 3/16/26.
//

import AppKit

/// Manages the docking logic: detecting proximity, showing previews, and executing merges
class DockingManager {
    static let shared = DockingManager()
    private init() {}

    private var overlayWindow: NSWindow?
    private var currentTarget: (controller: NoteWindowController, edge: DockEdge, leafID: UUID)?

    /// Called continuously while a note window is being moved
    func windowDidMove(_ movingController: NoteWindowController) {
        guard let movingWindow = movingController.window else { return }

        if let target = WindowTracker.shared.findDockTarget(for: movingWindow) {
            showDockPreview(on: target.controller, edge: target.edge)
            currentTarget = target
        } else {
            hideDockPreview()
            currentTarget = nil
        }
    }

    /// Called when window move ends (mouse up / window settled)
    func windowDidEndMove(_ movingController: NoteWindowController) {
        defer { hideDockPreview() }

        guard let target = currentTarget else { return }

        // Execute the merge
        executeDock(
            source: movingController,
            target: target.controller,
            edge: target.edge,
            leafID: target.leafID
        )
        currentTarget = nil
    }

    // MARK: - Dock Preview

    private func showDockPreview(on controller: NoteWindowController, edge: DockEdge) {
        guard let targetWindow = controller.window else { return }
        let targetFrame = targetWindow.frame

        // Calculate the preview rect (half the window)
        let previewRect: NSRect
        switch edge {
        case .left:
            previewRect = NSRect(x: targetFrame.minX, y: targetFrame.minY,
                                 width: targetFrame.width / 2, height: targetFrame.height)
        case .right:
            previewRect = NSRect(x: targetFrame.midX, y: targetFrame.minY,
                                 width: targetFrame.width / 2, height: targetFrame.height)
        case .top:
            previewRect = NSRect(x: targetFrame.minX, y: targetFrame.midY,
                                 width: targetFrame.width, height: targetFrame.height / 2)
        case .bottom:
            previewRect = NSRect(x: targetFrame.minX, y: targetFrame.minY,
                                 width: targetFrame.width, height: targetFrame.height / 2)
        }

        if overlayWindow == nil {
            let window = NSWindow(
                contentRect: previewRect,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.3)
            window.level = .floating
            window.ignoresMouseEvents = true
            window.hasShadow = false
            overlayWindow = window
        }

        overlayWindow?.setFrame(previewRect, display: true)
        overlayWindow?.orderFront(nil)
    }

    private func hideDockPreview() {
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
    }

    // MARK: - Execute Dock

    private func executeDock(
        source: NoteWindowController,
        target: NoteWindowController,
        edge: DockEdge,
        leafID: UUID
    ) {
        // Get documents from source
        let sourceDocuments = source.windowState.rootNode.allLeaves.map { $0.document }
        guard let sourceDoc = sourceDocuments.first else { return }

        // Save source frames for positioning
        let sourceFrame = source.window?.frame ?? .zero
        let targetFrame = target.window?.frame ?? .zero

        // Calculate merged frame
        let mergedFrame: NSRect
        switch edge {
        case .left:
            mergedFrame = NSRect(
                x: min(sourceFrame.minX, targetFrame.minX),
                y: min(sourceFrame.minY, targetFrame.minY),
                width: sourceFrame.width + targetFrame.width,
                height: max(sourceFrame.height, targetFrame.height)
            )
        case .right:
            mergedFrame = NSRect(
                x: min(sourceFrame.minX, targetFrame.minX),
                y: min(sourceFrame.minY, targetFrame.minY),
                width: sourceFrame.width + targetFrame.width,
                height: max(sourceFrame.height, targetFrame.height)
            )
        case .top:
            mergedFrame = NSRect(
                x: min(sourceFrame.minX, targetFrame.minX),
                y: min(sourceFrame.minY, targetFrame.minY),
                width: max(sourceFrame.width, targetFrame.width),
                height: sourceFrame.height + targetFrame.height
            )
        case .bottom:
            mergedFrame = NSRect(
                x: min(sourceFrame.minX, targetFrame.minX),
                y: min(sourceFrame.minY, targetFrame.minY),
                width: max(sourceFrame.width, targetFrame.width),
                height: sourceFrame.height + targetFrame.height
            )
        }

        // Dock the source document into the target window state
        target.windowState.dock(document: sourceDoc, onto: leafID, edge: edge)

        // Resize target window to merged frame
        target.window?.setFrame(mergedFrame, display: true, animate: true)
        target.rebuildContentView()

        // Close source window
        source.window?.close()
        WindowTracker.shared.unregister(source)
    }
}
