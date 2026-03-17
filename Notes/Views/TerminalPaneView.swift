//
//  TerminalPaneView.swift
//  Notes
//
//  Created by Nick Rizk on 3/17/26.
//

import AppKit
import SwiftTerm

/// A terminal pane that wraps LocalProcessTerminalView with the same focus indicator as NoteEditorView
class TerminalPaneView: NSView {
    let terminalView: LocalProcessTerminalView
    var isFocused: Bool = false {
        didSet { updateFocusIndicator() }
    }

    private let focusIndicator = NSView()
    private var clickMonitor: Any?

    init() {
        self.terminalView = LocalProcessTerminalView(frame: .zero)
        super.init(frame: .zero)
        terminalView.configureNativeColors()
        setupViews()
        startShell()
        setupClickMonitor()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        // Focus indicator (left border) — same pattern as NoteEditorView
        focusIndicator.wantsLayer = true
        focusIndicator.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        focusIndicator.isHidden = true

        addSubview(focusIndicator)
        addSubview(terminalView)

        // Hide the terminal's built-in vertical scroller to match NoteEditorView behavior.
        // SwiftTerm adds an NSScroller directly as a subview of TerminalView.
        if let scroller = terminalView.subviews.first(where: { $0 is NSScroller }) as? NSScroller {
            scroller.isHidden = true
        }

        focusIndicator.translatesAutoresizingMaskIntoConstraints = false
        terminalView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            focusIndicator.leadingAnchor.constraint(equalTo: leadingAnchor),
            focusIndicator.topAnchor.constraint(equalTo: topAnchor),
            focusIndicator.bottomAnchor.constraint(equalTo: bottomAnchor),
            focusIndicator.widthAnchor.constraint(equalToConstant: 2),

            terminalView.leadingAnchor.constraint(equalTo: focusIndicator.trailingAnchor),
            terminalView.trailingAnchor.constraint(equalTo: trailingAnchor),
            terminalView.topAnchor.constraint(equalTo: topAnchor),
            terminalView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func startShell() {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let loginName = "-" + (shell as NSString).lastPathComponent

        let cwd: String
        if let folder = FolderSettings.shared.folderURL {
            cwd = folder.path
        } else {
            cwd = NSHomeDirectory()
        }

        // Inherit current environment and set TERM
        var env = Array(ProcessInfo.processInfo.environment.map { "\($0.key)=\($0.value)" })
        // Override TERM to ensure color support
        env.removeAll { $0.hasPrefix("TERM=") }
        env.append("TERM=xterm-256color")

        terminalView.startProcess(
            executable: shell,
            args: [],
            environment: env,
            execName: loginName,
            currentDirectory: cwd
        )
    }

    private func updateFocusIndicator() {
        focusIndicator.isHidden = !isFocused
    }

    private func setupClickMonitor() {
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self else { return event }
            // Check if the click landed inside our terminal view
            let locationInTerminal = self.terminalView.convert(event.locationInWindow, from: nil)
            if self.terminalView.bounds.contains(locationInTerminal) {
                // Notify on next run loop tick so the terminal handles the click first
                DispatchQueue.main.async { self.notifyFocusGained() }
            }
            return event
        }
    }

    func focus() {
        window?.makeFirstResponder(terminalView)
    }

    func notifyFocusGained() {
        if let controller = window.flatMap({ WindowTracker.shared.controller(for: $0) }) {
            controller.terminalDidFocus(self)
        }
    }

    deinit {
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
        }
        terminalView.terminate()
    }
}
