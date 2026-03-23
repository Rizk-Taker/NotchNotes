//
//  NoteEditorView.swift
//  Notes
//
//  Created by Nick Rizk on 3/16/26.
//

import AppKit

/// Custom NSTextView subclass that notifies its parent NoteEditorView on focus
class PaneTextView: NSTextView {
    weak var editorView: NoteEditorView?

    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        if result {
            editorView?.notifyFocusGained()
        }
        return result
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        // Also notify on click in case becomeFirstResponder was already true
        editorView?.notifyFocusGained()
    }
}

/// A plain NSTextView wrapped in an NSScrollView for editing a single note
class NoteEditorView: NSView {
    let scrollView: NSScrollView
    let textView: PaneTextView
    let document: NoteDocument
    var isFocused: Bool = false {
        didSet { updateFocusIndicator() }
    }

    private let focusIndicator = NSView()
    private static var fontSize: CGFloat = 13

    static func adjustFontSize(delta: CGFloat) {
        fontSize = max(9, min(36, fontSize + delta))
    }

    init(document: NoteDocument) {
        self.document = document
        self.scrollView = NSScrollView()
        self.textView = PaneTextView()
        self.textView.editorView = nil  // Set after super.init
        super.init(frame: .zero)
        self.textView.editorView = self
        setupViews()
        textView.string = document.text
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        // Configure scroll view
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        // Configure text view
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.font = NSFont.monospacedSystemFont(ofSize: Self.fontSize, weight: .regular)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.drawsBackground = true
        textView.textContainerInset = NSSize(width: 12, height: 12)

        // Make text view resize with scroll view
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        textView.delegate = self

        scrollView.documentView = textView

        // Focus indicator (left border)
        focusIndicator.wantsLayer = true
        focusIndicator.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        focusIndicator.alphaValue = 0

        addSubview(scrollView)
        addSubview(focusIndicator)

        // Accessibility
        setAccessibilityRole(.group)
        setAccessibilityLabel("Editor pane — \(document.displayName)")

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        focusIndicator.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            focusIndicator.leadingAnchor.constraint(equalTo: leadingAnchor),
            focusIndicator.topAnchor.constraint(equalTo: topAnchor),
            focusIndicator.bottomAnchor.constraint(equalTo: bottomAnchor),
            focusIndicator.widthAnchor.constraint(equalToConstant: 2),

            scrollView.leadingAnchor.constraint(equalTo: focusIndicator.trailingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func updateFocusIndicator() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            focusIndicator.animator().alphaValue = isFocused ? 1 : 0
        }
    }

    func updateFont() {
        textView.font = NSFont.monospacedSystemFont(ofSize: Self.fontSize, weight: .regular)
    }

    func focus() {
        window?.makeFirstResponder(textView)
    }

    func notifyFocusGained() {
        if let controller = window.flatMap({ WindowTracker.shared.controller(for: $0) }) {
            controller.editorDidFocus(self)
        }
    }
}

// MARK: - NSTextViewDelegate

extension NoteEditorView: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        document.textDidChange(textView.string)
    }
}
