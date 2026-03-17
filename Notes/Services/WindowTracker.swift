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

    func createNewTerminal() {
        // Create a note window, then immediately split it with a terminal
        // so the terminal has a window to live in
        let document = NoteDocument()
        let controller = NoteWindowController(document: document)
        register(controller)
        controller.showWindow(nil)
        controller.splitFocusedPaneWithTerminal(orientation: .vertical)
        // Remove the empty note pane, leaving just the terminal
        if let noteLeafID = controller.windowState.rootNode.allLeaves.first(where: { !$0.isTerminal })?.id {
            controller.windowState.removePane(leafID: noteLeafID)
            controller.rebuildContentView()
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func openFile(url: URL) {
        // Check if already open
        if let existing = controllers.first(where: {
            $0.windowState.focusedDocument?.fileURL == url ||
            $0.windowState.rootNode.allLeaves.contains(where: { $0.document?.fileURL == url })
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

    /// Result of a dock zone detection
    struct DockZoneTarget {
        let controller: NoteWindowController
        let zone: DockZone
        let edge: DockEdge
        let leafID: UUID
    }

    /// Finds the dock target by checking if the cursor is inside another note window.
    /// Returns the target controller, which zone the cursor is in, and the corresponding DockEdge.
    func findDockTarget(for movingWindow: NSWindow, cursorLocation: NSPoint) -> DockZoneTarget? {
        for controller in controllers {
            guard let targetWindow = controller.window,
                  targetWindow !== movingWindow else { continue }

            let targetFrame = targetWindow.frame

            // Check if cursor is inside this window's frame
            guard targetFrame.contains(cursorLocation) else { continue }

            guard let leafID = controller.windowState.focusedLeafID
                ?? controller.windowState.rootNode.allLeaves.first?.id else { continue }

            // Determine which zone the cursor is in
            let zone = DockZoneOverlayView.zoneForPoint(cursorLocation, in: targetFrame)

            if zone == .none {
                // Cursor is in the center — show overlay but no specific zone
                return DockZoneTarget(controller: controller, zone: .none, edge: .right, leafID: leafID)
            }

            // Map DockZone to DockEdge
            let edge: DockEdge
            switch zone {
            case .left:   edge = .left
            case .right:  edge = .right
            case .top:    edge = .top
            case .bottom: edge = .bottom
            case .none:   edge = .right
            }

            return DockZoneTarget(controller: controller, zone: zone, edge: edge, leafID: leafID)
        }
        return nil
    }
}
