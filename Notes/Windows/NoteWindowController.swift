//
//  NoteWindowController.swift
//  Notes
//
//  Created by Nick Rizk on 3/16/26.
//

import AppKit
import UniformTypeIdentifiers

/// Manages a note window — can be a single pane or a split layout
class NoteWindowController: NSWindowController, NSWindowDelegate {

    let windowState: WindowState
    private var paneTreeView: PaneTreeView?
    private var moveObserver: Any?
    private static var cascadePoint = NSPoint(x: 200, y: 200)

    // MARK: - Init

    init(document: NoteDocument) {
        self.windowState = WindowState(document: document)

        let windowWidth: CGFloat = 700
        let windowHeight: CGFloat = 500

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 250, height: 200)
        window.title = document.fileURL != nil ? document.displayName : "NotchPad"
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.delegate = self

        // Position centered horizontally, near the top of the screen (below notch)
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - windowWidth / 2
            let y = screenFrame.maxY - windowHeight - 40
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        setupContentView()
        observeWindowMove()
    }

    init(windowState: WindowState, frame: NSRect) {
        self.windowState = windowState

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.minSize = NSSize(width: 250, height: 200)
        window.title = windowState.focusedDocument?.fileURL != nil ? windowState.focusedDocument?.displayName ?? "NotchPad" : "NotchPad"
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.delegate = self

        setupContentView()
        observeWindowMove()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Content View

    private func setupContentView() {
        let treeView = PaneTreeView(node: windowState.rootNode, windowController: self)
        treeView.update(node: windowState.rootNode, focusedLeafID: windowState.focusedLeafID)
        self.paneTreeView = treeView
        window?.contentView = treeView
    }

    func rebuildContentView() {
        paneTreeView?.update(node: windowState.rootNode, focusedLeafID: windowState.focusedLeafID)
        updateTitle()
    }

    // MARK: - Focus

    func editorDidFocus(_ editor: NoteEditorView) {
        if let entry = paneTreeView?.editorViews.first(where: { $0.value === editor }) {
            windowState.focusedLeafID = entry.key
            updateAllFocusIndicators(focusedID: entry.key)
            updateTitle()
        }
    }

    func terminalDidFocus(_ terminal: TerminalPaneView) {
        if let entry = paneTreeView?.terminalViews.first(where: { $0.value === terminal }) {
            windowState.focusedLeafID = entry.key
            updateAllFocusIndicators(focusedID: entry.key)
            updateTitle()
        }
    }

    private func updateAllFocusIndicators(focusedID: UUID) {
        for (id, editorView) in paneTreeView?.editorViews ?? [:] {
            editorView.isFocused = (id == focusedID)
        }
        for (id, terminalView) in paneTreeView?.terminalViews ?? [:] {
            terminalView.isFocused = (id == focusedID)
        }
    }

    private func updateTitle() {
        if let leaf = windowState.focusedLeaf, leaf.isTerminal {
            window?.title = "NotchPad — Terminal"
        } else {
            window?.title = windowState.focusedDocument?.fileURL != nil ? (windowState.focusedDocument?.displayName ?? "NotchPad") : "NotchPad"
        }
    }

    // MARK: - Pane Navigation (⌥⌘ Arrow Keys)

    func moveFocus(direction: DockEdge) {
        let leaves = windowState.rootNode.allLeaves
        guard leaves.count > 1,
              let currentIndex = leaves.firstIndex(where: { $0.id == windowState.focusedLeafID }) else { return }

        let nextIndex: Int
        switch direction {
        case .right, .bottom:
            nextIndex = (currentIndex + 1) % leaves.count
        case .left, .top:
            nextIndex = (currentIndex - 1 + leaves.count) % leaves.count
        }

        let targetLeaf = leaves[nextIndex]
        windowState.focusedLeafID = targetLeaf.id
        rebuildContentView()

        // Focus the appropriate view type
        if let editor = paneTreeView?.editorViews[targetLeaf.id] {
            editor.focus()
        } else if let terminal = paneTreeView?.terminalViews[targetLeaf.id] {
            terminal.focus()
        }
    }

    // MARK: - Split Pane

    func splitFocusedPane(orientation: SplitOrientation) {
        guard let leafID = windowState.focusedLeafID else { return }
        let newDoc = NoteDocument()
        let edge: DockEdge = (orientation == .vertical) ? .right : .bottom
        windowState.dock(document: newDoc, onto: leafID, edge: edge)
        rebuildContentView()

        // Focus the new pane's text view
        if let newLeafID = windowState.focusedLeafID,
           let editor = paneTreeView?.editorViews[newLeafID] {
            editor.focus()
        }
    }

    func splitFocusedPaneWithTerminal(orientation: SplitOrientation) {
        guard let leafID = windowState.focusedLeafID else { return }
        let edge: DockEdge = (orientation == .vertical) ? .right : .bottom
        windowState.dockTerminal(onto: leafID, edge: edge)
        rebuildContentView()

        if let newLeafID = windowState.focusedLeafID,
           let terminal = paneTreeView?.terminalViews[newLeafID] {
            terminal.focus()
        }
    }

    // MARK: - Save

    func saveFocusedPane() {
        guard let doc = windowState.focusedDocument else { return }
        if doc.fileURL == nil {
            doc.saveNew { [weak self] _ in
                self?.updateTitle()
            }
        } else {
            doc.save()
        }
    }

    func saveFocusedPaneAs() {
        guard let doc = windowState.focusedDocument else { return }
        let panel = NSSavePanel()
        let ext = UserDefaults.standard.string(forKey: "fileExtension") ?? "md"
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(doc.displayName).\(ext)"
        if let folder = FolderSettings.shared.folderURL {
            panel.directoryURL = folder
        }
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            doc.saveAs(url: url)
            self.updateTitle()
        }
    }

    // MARK: - Close Pane

    func closeFocusedPane() {
        guard let leafID = windowState.focusedLeafID else { return }
        guard let leaf = windowState.focusedLeaf else { return }

        // Terminal panes close immediately
        if leaf.isTerminal {
            removePane(leafID: leafID)
            return
        }

        guard let doc = leaf.document else { return }
        if doc.isDirty && !doc.text.isEmpty {
            promptSaveBeforeClose(doc: doc) { [weak self] shouldProceed in
                guard shouldProceed, let self else { return }
                self.removePane(leafID: leafID)
            }
        } else {
            removePane(leafID: leafID)
        }
    }

    private func removePane(leafID: UUID) {
        if windowState.isSinglePane {
            window?.close()
        } else {
            windowState.removePane(leafID: leafID)
            rebuildContentView()
        }
    }

    /// Keyboard-driven Y/N save prompt
    private func promptSaveBeforeClose(doc: NoteDocument, completion: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Save before closing?"
        if let url = doc.fileURL {
            alert.informativeText = "Press Y to save to \(url.lastPathComponent), N to discard"
        } else {
            alert.informativeText = "Press Y to save, N to discard"
        }
        alert.addButton(withTitle: "Save (Y)")
        alert.addButton(withTitle: "Discard (N)")

        // Track what the user chose via keyboard
        enum Choice { case save, discard, cancel }
        var choice: Choice?

        var keyMonitor: Any?
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let key = event.charactersIgnoringModifiers?.lowercased()
            if key == "y" {
                choice = .save
                NSApp.abortModal()
                return nil
            } else if key == "n" {
                choice = .discard
                NSApp.abortModal()
                return nil
            } else if event.keyCode == 53 {
                choice = .cancel
                NSApp.abortModal()
                return nil
            }
            return event
        }

        let response = alert.runModal()
        if let monitor = keyMonitor { NSEvent.removeMonitor(monitor) }

        // Determine action from keyboard choice or button click
        let action: Choice = choice ?? (response == .alertFirstButtonReturn ? .save : .discard)

        switch action {
        case .save:
            if doc.fileURL != nil {
                doc.save()
                completion(true)
            } else {
                doc.saveNew { _ in
                    completion(true)
                }
            }
        case .discard:
            completion(true)
        case .cancel:
            completion(false)
        }
    }

    // MARK: - Font Size

    func adjustFontSize(delta: CGFloat) {
        NoteEditorView.adjustFontSize(delta: delta)
        for (_, editor) in paneTreeView?.editorViews ?? [:] {
            editor.updateFont()
        }
    }

    // MARK: - Window Move Observation (for docking)

    private func observeWindowMove() {
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            DockingManager.shared.windowDidMove(self)
        }
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        WindowTracker.shared.unregister(self)
        if let observer = moveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        // Could be used for layout recalculation
    }

    /// Detect when window drag ends to check for docking
    func windowDidMove(_ notification: Notification) {
        // This is also handled via NotificationCenter observer above
    }

    deinit {
        // Cleanup handled by windowWillClose
    }
}
