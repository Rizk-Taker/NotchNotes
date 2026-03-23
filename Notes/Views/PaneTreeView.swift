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
        // Cache both terminal and editor views so sessions/state survive rebuilds
        let previousTerminals = terminalViews
        let previousEditors = editorViews
        // Rebuild the view hierarchy
        subviews.forEach { $0.removeFromSuperview() }
        editorViews.removeAll()
        terminalViews.removeAll()
        buildView(previousTerminals: previousTerminals, previousEditors: previousEditors)
        // Update focus indicators
        for (id, editor) in editorViews {
            editor.isFocused = (id == focusedLeafID)
        }
        for (id, terminal) in terminalViews {
            terminal.isFocused = (id == focusedLeafID)
        }
    }

    /// Performs an animated update — snapshot the current state, rebuild, then crossfade.
    func animatedUpdate(node: PaneNode, focusedLeafID: UUID?) {
        // Snapshot current appearance
        guard let snapshot = self.snapshotView() else {
            update(node: node, focusedLeafID: focusedLeafID)
            return
        }

        // Perform the rebuild (instant, under the snapshot)
        update(node: node, focusedLeafID: focusedLeafID)

        // Overlay the snapshot and fade it out
        snapshot.frame = bounds
        snapshot.wantsLayer = true
        addSubview(snapshot)

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            snapshot.animator().alphaValue = 0
        }, completionHandler: {
            snapshot.removeFromSuperview()
        })
    }

    /// Creates a bitmap snapshot of the current view hierarchy
    private func snapshotView() -> NSView? {
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        guard let bitmapRep = bitmapImageRepForCachingDisplay(in: bounds) else { return nil }
        cacheDisplay(in: bounds, to: bitmapRep)
        let image = NSImage(size: bounds.size)
        image.addRepresentation(bitmapRep)
        let imageView = NSImageView(frame: bounds)
        imageView.image = image
        imageView.imageScaling = .scaleNone
        return imageView
    }

    private func buildView(previousTerminals: [UUID: TerminalPaneView] = [:], previousEditors: [UUID: NoteEditorView] = [:]) {
        let child = createView(for: node, previousTerminals: previousTerminals, previousEditors: previousEditors)
        addSubview(child)
        child.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            child.leadingAnchor.constraint(equalTo: leadingAnchor),
            child.trailingAnchor.constraint(equalTo: trailingAnchor),
            child.topAnchor.constraint(equalTo: topAnchor),
            child.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func createView(for node: PaneNode, previousTerminals: [UUID: TerminalPaneView], previousEditors: [UUID: NoteEditorView] = [:]) -> NSView {
        switch node {
        case .leaf(let leaf):
            switch leaf.content {
            case .editor(let document):
                // Reuse existing editor if same leaf and same document
                if let cached = previousEditors[leaf.id], cached.document.id == document.id {
                    editorViews[leaf.id] = cached
                    return cached
                }
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
            splitView.onRatioChange = { [weak self] splitID, newRatio in
                guard let self, let wc = self.windowController else { return }
                wc.windowState.updateSplitRatio(splitID: splitID, ratio: newRatio)
            }
            let firstView = createView(for: split.first, previousTerminals: previousTerminals, previousEditors: previousEditors)
            let secondView = createView(for: split.second, previousTerminals: previousTerminals, previousEditors: previousEditors)
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

    /// Callback when the user drags the divider — sends (splitID, newRatio)
    var onRatioChange: ((UUID, CGFloat) -> Void)?

    private var firstView: NSView?
    private var secondView: NSView?
    private var divider: PaneDividerView?
    private var dividerConstraint: NSLayoutConstraint?
    /// Visual indicator shown when the divider snaps to center (50%)
    private var centerLineView: NSView?

    private static let dividerThickness: CGFloat = 3
    /// Minimum absolute pane size: 120px for vertical splits (width), 80px for horizontal (height)
    private var minimumPaneSize: CGFloat {
        orientation == .vertical ? 120 : 80
    }

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
        div.onDoubleClick = { [weak self] in
            self?.equalizeSplit()
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
        var newRatio = ratio + ratioDelta

        // Enforce minimum absolute pane size
        let availableSize = totalSize - Self.dividerThickness
        let minRatio = minimumPaneSize / availableSize
        let maxRatio = 1.0 - minRatio
        newRatio = max(minRatio, min(maxRatio, newRatio))

        // Snap to center when within 3% of 0.5
        let isSnapped = abs(newRatio - 0.5) < 0.03
        if isSnapped {
            newRatio = 0.5
        }

        ratio = newRatio

        // Show/hide center-line indicator when snapped
        updateCenterLineIndicator(visible: isSnapped)

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

        // Persist ratio back to the model
        onRatioChange?(splitID, ratio)
    }

    private func equalizeSplit() {
        ratio = 0.5

        if let old = dividerConstraint {
            old.isActive = false
            let divThickness = Self.dividerThickness
            let newConstraint: NSLayoutConstraint
            switch orientation {
            case .vertical:
                newConstraint = firstView!.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.5, constant: -divThickness * 0.5)
            case .horizontal:
                newConstraint = firstView!.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 0.5, constant: -divThickness * 0.5)
            }
            newConstraint.isActive = true
            dividerConstraint = newConstraint
        }

        // Commit current layout state before animating
        self.layoutSubtreeIfNeeded()

        // Animate to equalized layout
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.layoutSubtreeIfNeeded()
        }

        onRatioChange?(splitID, 0.5)
    }

    private func updateCenterLineIndicator(visible: Bool) {
        if visible {
            if centerLineView == nil {
                let line = NSView()
                line.wantsLayer = true
                line.layer?.backgroundColor = NSColor.tertiaryLabelColor.cgColor
                line.translatesAutoresizingMaskIntoConstraints = false
                addSubview(line)
                switch orientation {
                case .vertical:
                    NSLayoutConstraint.activate([
                        line.centerXAnchor.constraint(equalTo: centerXAnchor),
                        line.topAnchor.constraint(equalTo: topAnchor),
                        line.bottomAnchor.constraint(equalTo: bottomAnchor),
                        line.widthAnchor.constraint(equalToConstant: 1),
                    ])
                case .horizontal:
                    NSLayoutConstraint.activate([
                        line.centerYAnchor.constraint(equalTo: centerYAnchor),
                        line.leadingAnchor.constraint(equalTo: leadingAnchor),
                        line.trailingAnchor.constraint(equalTo: trailingAnchor),
                        line.heightAnchor.constraint(equalToConstant: 1),
                    ])
                }
                centerLineView = line
            }
            centerLineView?.alphaValue = 1
        } else {
            centerLineView?.alphaValue = 0
        }
    }
}
