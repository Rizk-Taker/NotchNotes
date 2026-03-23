//
//  DockingManager.swift
//  Notes
//
//  Created by Nick Rizk on 3/16/26.
//

import AppKit

/// Manages the docking logic: detecting cursor-over-window zones, showing previews,
/// and executing merges (iTerm2-style)
class DockingManager {
    static let shared = DockingManager()
    private init() {}

    private var overlayWindow: NSWindow?
    private var overlayView: DockZoneOverlayView?
    private var currentTarget: WindowTracker.DockZoneTarget?

    /// The controller whose window is currently being dragged
    private var draggingController: NoteWindowController?
    private var mouseUpMonitor: Any?

    /// Whether a window drag is in progress
    private(set) var isDragging = false

    /// Called continuously while a note window is being moved
    func windowDidMove(_ movingController: NoteWindowController) {
        guard let movingWindow = movingController.window else { return }

        isDragging = true
        draggingController = movingController

        // Install a centralized mouseUp monitor on first drag detection
        if mouseUpMonitor == nil {
            mouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
                self?.handleMouseUp()
                return event
            }
        }

        let cursorLocation = NSEvent.mouseLocation

        if let target = WindowTracker.shared.findDockTarget(
            for: movingWindow, cursorLocation: cursorLocation
        ) {
            showDockPreview(on: target.controller, zone: target.zone)
            currentTarget = target
        } else {
            hideDockPreview()
            currentTarget = nil
        }
    }

    /// Handles mouseUp — executes dock if valid, then cleans up
    private func handleMouseUp() {
        defer {
            hideDockPreview()
            isDragging = false
            if let monitor = mouseUpMonitor {
                NSEvent.removeMonitor(monitor)
                mouseUpMonitor = nil
            }
        }

        guard let controller = draggingController else { return }
        draggingController = nil

        guard let target = currentTarget, target.zone != .none else {
            currentTarget = nil
            return
        }

        executeDock(
            source: controller,
            target: target.controller,
            edge: target.edge,
            leafID: target.leafID
        )
        currentTarget = nil
    }

    // MARK: - Dock Preview (Zone Overlay)

    private func showDockPreview(on controller: NoteWindowController, zone: DockZone) {
        guard let targetWindow = controller.window else { return }
        let targetFrame = targetWindow.frame

        if overlayWindow == nil {
            let view = DockZoneOverlayView(frame: NSRect(origin: .zero, size: targetFrame.size))

            let window = NSWindow(
                contentRect: targetFrame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .floating
            window.ignoresMouseEvents = true
            window.hasShadow = false
            window.contentView = view

            overlayWindow = window
            overlayView = view
        }

        // Cover the entire target window
        overlayWindow?.setFrame(targetFrame, display: false)
        overlayView?.frame = NSRect(origin: .zero, size: targetFrame.size)
        overlayView?.activeZone = zone
        overlayWindow?.orderFront(nil)
    }

    private func hideDockPreview() {
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        overlayView = nil
    }

    // MARK: - Execute Dock

    private func executeDock(
        source: NoteWindowController,
        target: NoteWindowController,
        edge: DockEdge,
        leafID: UUID
    ) {
        // Get the first leaf from source
        guard let sourceLeaf = source.windowState.rootNode.allLeaves.first else { return }

        // Dock the source pane into the target window state
        // The target window keeps its current size — the source merges into it
        if let sourceDoc = sourceLeaf.document {
            target.windowState.dock(document: sourceDoc, onto: leafID, edge: edge)
        } else if sourceLeaf.isTerminal {
            target.windowState.dockTerminal(onto: leafID, edge: edge)
        }

        target.rebuildContentView(animated: true)

        // Close source window
        source.window?.close()
        WindowTracker.shared.unregister(source)
    }
}
