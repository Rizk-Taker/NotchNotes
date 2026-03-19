//
//  PaneTreeView.swift
//  Notes
//
//  Created by Nick Rizk on 3/16/26.
//

import AppKit

/// Recursively renders a PaneNode tree into nested NSViews with dividers
class PaneTreeView: NSView {
    private var node: PaneNode
    private weak var windowController: NoteWindowController?

    /// All leaf editor views in this tree (for focus management)
    private(set) var editorViews: [UUID: NoteEditorView] = [:]
    /// All leaf terminal views in this tree (for focus management)
    private(set) var terminalViews: [UUID: TerminalPaneView] = [:]

    init(node: PaneNode, windowController: NoteWindowController?) {
        self.node = node
        self.windowController = windowController
        super.init(frame: .zero)
        buildView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Key Equivalents
    // Intercept app shortcuts before they reach the terminal view.
    // TUI apps (e.g. Claude Code) enable the Kitty keyboard protocol which can
    // prevent menu-bar key equivalents from firing.  By handling them here — at the
    // content-view level — the shortcuts work regardless of terminal state, matching
    // iTerm behaviour.

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags
        let hasCmd = flags.contains(.command)
        let hasShift = flags.contains(.shift)
        let hasOpt = flags.contains(.option)

        guard hasCmd, let chars = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }

        // ⌘D / ⇧⌘D — split with editor
        if chars == "d" && !hasOpt {
            let orientation: SplitOrientation = hasShift ? .horizontal : .vertical
            windowController?.splitFocusedPane(orientation: orientation)
            return true
        }

        // ⌘T / ⇧⌘T — split with terminal
        if chars == "t" && !hasOpt {
            let orientation: SplitOrientation = hasShift ? .horizontal : .vertical
            windowController?.splitFocusedPaneWithTerminal(orientation: orientation)
            return true
        }

        // ⌘W — close pane
        if chars == "w" && !hasShift && !hasOpt {
            windowController?.closeFocusedPane()
            return true
        }

        // ⌥⌘ Arrow — pane navigation
        if hasOpt, let scalar = chars.unicodeScalars.first {
            switch Int(scalar.value) {
            case NSLeftArrowFunctionKey:
                windowController?.moveFocus(direction: .left)
                return true
            case NSRightArrowFunctionKey:
                windowController?.moveFocus(direction: .right)
                return true
            case NSUpArrowFunctionKey:
                windowController?.moveFocus(direction: .top)
                return true
            case NSDownArrowFunctionKey:
                windowController?.moveFocus(direction: .bottom)
                return true
            default:
                break
            }
        }

        return super.performKeyEquivalent(with: event)
    }

    func update(node: PaneNode, focusedLeafID: UUID?) {
        self.node = node
        // Cache terminal views so shell sessions survive rebuilds
        let previousTerminals = terminalViews
        // Rebuild the view hierarchy
        subviews.forEach { $0.removeFromSuperview() }
        editorViews.removeAll()
        terminalViews.removeAll()
        buildView(previousTerminals: previousTerminals)
        // Update focus indicators
        for (id, editor) in editorViews {
            editor.isFocused = (id == focusedLeafID)
        }
        for (id, terminal) in terminalViews {
            terminal.isFocused = (id == focusedLeafID)
        }
    }

    private func buildView(previousTerminals: [UUID: TerminalPaneView] = [:]) {
        let child = createView(for: node, previousTerminals: previousTerminals)
        addSubview(child)
        child.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            child.leadingAnchor.constraint(equalTo: leadingAnchor),
            child.trailingAnchor.constraint(equalTo: trailingAnchor),
            child.topAnchor.constraint(equalTo: topAnchor),
            child.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func createView(for node: PaneNode, previousTerminals: [UUID: TerminalPaneView]) -> NSView {
        switch node {
        case .leaf(let leaf):
            switch leaf.content {
            case .editor(let document):
                let editor = NoteEditorView(document: document)
                editorViews[leaf.id] = editor
                return editor
            case .terminal:
                // Reuse existing terminal view to preserve the shell session
                let terminal = previousTerminals[leaf.id] ?? TerminalPaneView()
                terminalViews[leaf.id] = terminal
                return terminal
            }

        case .split(let split):
            let splitView = PaneSplitView(
                orientation: split.orientation,
                ratio: split.ratio,
                splitID: split.id
            )
            let firstView = createView(for: split.first, previousTerminals: previousTerminals)
            let secondView = createView(for: split.second, previousTerminals: previousTerminals)
            splitView.setViews(first: firstView, second: secondView)
            return splitView
        }
    }
}

// MARK: - PaneSplitView

/// A split view with a draggable divider
class PaneSplitView: NSView {
    let orientation: SplitOrientation
    var ratio: CGFloat
    let splitID: UUID

    private var firstView: NSView?
    private var secondView: NSView?
    private var divider: PaneDividerView?
    private var dividerConstraint: NSLayoutConstraint?

    private static let dividerThickness: CGFloat = 3

    init(orientation: SplitOrientation, ratio: CGFloat, splitID: UUID) {
        self.orientation = orientation
        self.ratio = ratio
        self.splitID = splitID
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setViews(first: NSView, second: NSView) {
        self.firstView = first
        self.secondView = second

        let div = PaneDividerView(orientation: orientation)
        div.onDrag = { [weak self] delta in
            self?.handleDividerDrag(delta: delta)
        }
        self.divider = div

        addSubview(first)
        addSubview(div)
        addSubview(second)

        first.translatesAutoresizingMaskIntoConstraints = false
        div.translatesAutoresizingMaskIntoConstraints = false
        second.translatesAutoresizingMaskIntoConstraints = false

        setupConstraints(first: first, divider: div, second: second)
    }

    private func setupConstraints(first: NSView, divider div: PaneDividerView, second: NSView) {
        switch orientation {
        case .vertical:
            // Side by side
            let widthConstraint = first.widthAnchor.constraint(equalTo: widthAnchor, multiplier: ratio, constant: -Self.dividerThickness * ratio)

            NSLayoutConstraint.activate([
                first.leadingAnchor.constraint(equalTo: leadingAnchor),
                first.topAnchor.constraint(equalTo: topAnchor),
                first.bottomAnchor.constraint(equalTo: bottomAnchor),
                widthConstraint,

                div.leadingAnchor.constraint(equalTo: first.trailingAnchor),
                div.topAnchor.constraint(equalTo: topAnchor),
                div.bottomAnchor.constraint(equalTo: bottomAnchor),
                div.widthAnchor.constraint(equalToConstant: Self.dividerThickness),

                second.leadingAnchor.constraint(equalTo: div.trailingAnchor),
                second.trailingAnchor.constraint(equalTo: trailingAnchor),
                second.topAnchor.constraint(equalTo: topAnchor),
                second.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
            dividerConstraint = widthConstraint

        case .horizontal:
            // Stacked top/bottom
            let heightConstraint = first.heightAnchor.constraint(equalTo: heightAnchor, multiplier: ratio, constant: -Self.dividerThickness * ratio)

            NSLayoutConstraint.activate([
                first.leadingAnchor.constraint(equalTo: leadingAnchor),
                first.trailingAnchor.constraint(equalTo: trailingAnchor),
                first.topAnchor.constraint(equalTo: topAnchor),
                heightConstraint,

                div.leadingAnchor.constraint(equalTo: leadingAnchor),
                div.trailingAnchor.constraint(equalTo: trailingAnchor),
                div.topAnchor.constraint(equalTo: first.bottomAnchor),
                div.heightAnchor.constraint(equalToConstant: Self.dividerThickness),

                second.leadingAnchor.constraint(equalTo: leadingAnchor),
                second.trailingAnchor.constraint(equalTo: trailingAnchor),
                second.topAnchor.constraint(equalTo: div.bottomAnchor),
                second.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])
            dividerConstraint = heightConstraint
        }
    }

    private func handleDividerDrag(delta: CGFloat) {
        let totalSize: CGFloat
        switch orientation {
        case .vertical: totalSize = bounds.width
        case .horizontal: totalSize = bounds.height
        }
        guard totalSize > 0 else { return }

        let ratioDelta = delta / totalSize
        ratio = max(0.15, min(0.85, ratio + ratioDelta))

        // Update the constraint multiplier by replacing it
        if let old = dividerConstraint {
            old.isActive = false
            let divThickness = Self.dividerThickness
            let newConstraint: NSLayoutConstraint
            switch orientation {
            case .vertical:
                newConstraint = firstView!.widthAnchor.constraint(equalTo: widthAnchor, multiplier: ratio, constant: -divThickness * ratio)
            case .horizontal:
                newConstraint = firstView!.heightAnchor.constraint(equalTo: heightAnchor, multiplier: ratio, constant: -divThickness * ratio)
            }
            newConstraint.isActive = true
            dividerConstraint = newConstraint
        }
    }
}
