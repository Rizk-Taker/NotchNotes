//
//  AppDelegate.swift
//  Notes
//
//  Created by Nick Rizk on 3/16/26.
//

import AppKit
import UniformTypeIdentifiers

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var notchMonitor: NotchMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        setupMenuBar()
        setupStatusItem()

        // Request Accessibility permission (required for global event monitors)
        // This triggers the system prompt if not already granted
        requestAccessibilityIfNeeded()

        notchMonitor = NotchMonitor()
        notchMonitor?.start()

        // Show onboarding on first launch, otherwise open a note
        let hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        if !hasCompletedOnboarding {
            OnboardingWindowController.shared.showOnboarding()
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if WindowTracker.shared.allNoteWindows.isEmpty {
                    WindowTracker.shared.createNewNote()
                }
            }
        }
    }

    private func requestAccessibilityIfNeeded() {
        let trusted = AXIsProcessTrustedWithOptions(
            [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        )
        if !trusted {
            print("Accessibility permission not yet granted — global notch trigger won't work until enabled in System Settings > Privacy & Security > Accessibility")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            WindowTracker.shared.createNewNote()
        }
        return true
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        let mainMenu = NSMenu()

        // App menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About NotchNotes", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit NotchNotes", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // File menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "New Note", action: #selector(newNote), keyEquivalent: "n")
        fileMenu.addItem(withTitle: "Open…", action: #selector(openFile), keyEquivalent: "o")
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Save", action: #selector(saveNote), keyEquivalent: "s")

        let saveAsItem = NSMenuItem(title: "Save As…", action: #selector(saveNoteAs), keyEquivalent: "S")
        saveAsItem.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(saveAsItem)

        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Split Vertical", action: #selector(splitVertical), keyEquivalent: "d")
        let splitHItem = NSMenuItem(title: "Split Horizontal", action: #selector(splitHorizontal), keyEquivalent: "d")
        splitHItem.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(splitHItem)

        fileMenu.addItem(withTitle: "Terminal Vertical", action: #selector(splitWithTerminalVertical), keyEquivalent: "t")
        let terminalHItem = NSMenuItem(title: "Terminal Horizontal", action: #selector(splitWithTerminalHorizontal), keyEquivalent: "t")
        terminalHItem.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(terminalHItem)

        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Close Pane", action: #selector(closePane), keyEquivalent: "w")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // Edit menu
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: Selector(("cut:")), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: Selector(("copy:")), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: Selector(("paste:")), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Paste and Match Style", action: Selector(("pasteAsPlainText:")), keyEquivalent: "V")
        editMenu.addItem(withTitle: "Select All", action: Selector(("selectAll:")), keyEquivalent: "a")
        editMenu.addItem(NSMenuItem.separator())

        let findItem = NSMenuItem(title: "Find…", action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: "f")
        findItem.tag = Int(NSFindPanelAction.showFindPanel.rawValue)
        editMenu.addItem(findItem)
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // View menu
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")

        let zoomInItem = NSMenuItem(title: "Zoom In", action: #selector(zoomIn), keyEquivalent: "+")
        zoomInItem.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(zoomInItem)

        let zoomOutItem = NSMenuItem(title: "Zoom Out", action: #selector(zoomOut), keyEquivalent: "-")
        zoomOutItem.keyEquivalentModifierMask = [.command]
        viewMenu.addItem(zoomOutItem)

        viewMenu.addItem(NSMenuItem.separator())

        let focusLeftItem = NSMenuItem(title: "Focus Left Pane", action: #selector(focusLeft), keyEquivalent: String(Character(UnicodeScalar(NSLeftArrowFunctionKey)!)))
        focusLeftItem.keyEquivalentModifierMask = [.command, .option]
        viewMenu.addItem(focusLeftItem)

        let focusRightItem = NSMenuItem(title: "Focus Right Pane", action: #selector(focusRight), keyEquivalent: String(Character(UnicodeScalar(NSRightArrowFunctionKey)!)))
        focusRightItem.keyEquivalentModifierMask = [.command, .option]
        viewMenu.addItem(focusRightItem)

        let focusUpItem = NSMenuItem(title: "Focus Upper Pane", action: #selector(focusUp), keyEquivalent: String(Character(UnicodeScalar(NSUpArrowFunctionKey)!)))
        focusUpItem.keyEquivalentModifierMask = [.command, .option]
        viewMenu.addItem(focusUpItem)

        let focusDownItem = NSMenuItem(title: "Focus Lower Pane", action: #selector(focusDown), keyEquivalent: String(Character(UnicodeScalar(NSDownArrowFunctionKey)!)))
        focusDownItem.keyEquivalentModifierMask = [.command, .option]
        viewMenu.addItem(focusDownItem)

        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        // Window menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
    }

    // MARK: - Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "NotchNotes")
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "New Note", action: #selector(newNote), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Change Notes Folder…", action: #selector(changeFolder), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        statusItem?.menu = menu
    }

    // MARK: - Helpers

    /// Returns the active note window controller, falling back from keyWindow → mainWindow → frontmost note window.
    private func activeNoteController() -> NoteWindowController? {
        if let window = NSApp.keyWindow, let controller = WindowTracker.shared.controller(for: window) {
            return controller
        }
        if let window = NSApp.mainWindow, let controller = WindowTracker.shared.controller(for: window) {
            return controller
        }
        // Fall back to the frontmost note window
        for window in NSApp.orderedWindows {
            if let controller = WindowTracker.shared.controller(for: window) {
                return controller
            }
        }
        return nil
    }

    // MARK: - Actions

    @objc private func newNote() {
        WindowTracker.shared.createNewNote()
    }

    @objc private func openFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.plainText, .text]
        if let folder = FolderSettings.shared.folderURL {
            panel.directoryURL = folder
        }
        panel.begin { response in
            guard response == .OK else { return }
            for url in panel.urls {
                WindowTracker.shared.openFile(url: url)
            }
        }
    }

    @objc private func saveNote() {
        guard let controller = activeNoteController() else { return }
        controller.saveFocusedPane()
    }

    @objc private func saveNoteAs() {
        guard let controller = activeNoteController() else { return }
        controller.saveFocusedPaneAs()
    }

    @objc private func splitVertical() {
        guard let controller = activeNoteController() else { return }
        controller.splitFocusedPane(orientation: .vertical)
    }

    @objc private func splitHorizontal() {
        guard let controller = activeNoteController() else { return }
        controller.splitFocusedPane(orientation: .horizontal)
    }

    @objc private func splitWithTerminalVertical() {
        guard let controller = activeNoteController() else { return }
        controller.splitFocusedPaneWithTerminal(orientation: .vertical)
    }

    @objc private func splitWithTerminalHorizontal() {
        guard let controller = activeNoteController() else { return }
        controller.splitFocusedPaneWithTerminal(orientation: .horizontal)
    }

    @objc private func closePane() {
        guard let controller = activeNoteController() else { return }
        controller.closeFocusedPane()
    }

    @objc private func showSettings() {
        SettingsWindowController.shared.showSettings()
    }

    @objc private func changeFolder() {
        FolderSettings.shared.pickFolder()
    }

    @objc private func zoomIn() {
        guard let controller = activeNoteController() else { return }
        controller.adjustFontSize(delta: 1)
    }

    @objc private func zoomOut() {
        guard let controller = activeNoteController() else { return }
        controller.adjustFontSize(delta: -1)
    }

    @objc private func focusLeft() {
        guard let controller = activeNoteController() else { return }
        controller.moveFocus(direction: .left)
    }

    @objc private func focusRight() {
        guard let controller = activeNoteController() else { return }
        controller.moveFocus(direction: .right)
    }

    @objc private func focusUp() {
        guard let controller = activeNoteController() else { return }
        controller.moveFocus(direction: .top)
    }

    @objc private func focusDown() {
        guard let controller = activeNoteController() else { return }
        controller.moveFocus(direction: .bottom)
    }
}
