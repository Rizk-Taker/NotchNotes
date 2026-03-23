//
//  NotchMonitor.swift
//  Notes
//
//  Created by Nick Rizk on 3/16/26.
//

import AppKit

/// Monitors global mouse position to detect notch-area hover
class NotchMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var enterKeyGlobalMonitor: Any?
    private var enterKeyLocalMonitor: Any?
    private var triggerPanel: NotchTriggerPanel?
    private var hideTimer: Timer?
    private var isShowing = false

    func start() {
        // Global monitor for mouse moved events (works when app is not focused)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMoved()
        }

        // Local monitor for mouse moved events (works when app is focused)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMoved()
            return event
        }
    }

    func stop() {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        removeEnterKeyMonitor()
    }

    // MARK: - Notch Zone Detection

    private var notchZone: NSRect {
        guard let screen = NSScreen.main else { return .zero }
        let notchWidth = screen.notchWidth
        let safeTop = screen.safeAreaInsets.top
        let zoneHeight = max(safeTop, 32)  // Full notch height as the hover zone
        return NSRect(
            x: screen.frame.midX - notchWidth / 2,
            y: screen.frame.maxY - zoneHeight,
            width: notchWidth,
            height: zoneHeight
        )
    }

    private func handleMouseMoved() {
        let mouseLocation = NSEvent.mouseLocation
        if notchZone.contains(mouseLocation) {
            showTrigger()
        } else {
            scheduleDismiss()
        }
    }

    // MARK: - Trigger Panel

    private func showTrigger() {
        hideTimer?.invalidate()
        hideTimer = nil

        if isShowing { return }
        isShowing = true

        if triggerPanel == nil {
            triggerPanel = NotchTriggerPanel()
        }

        triggerPanel?.showAnimated()
        addEnterKeyMonitor()
    }

    private func scheduleDismiss() {
        guard isShowing else { return }
        hideTimer?.invalidate()
        hideTrigger()
    }

    private func hideTrigger() {
        isShowing = false
        triggerPanel?.hideAnimated()
        removeEnterKeyMonitor()
    }

    // MARK: - Enter Key

    private func addEnterKeyMonitor() {
        guard enterKeyGlobalMonitor == nil else { return }

        // Global monitor: fires when the app is NOT focused
        enterKeyGlobalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 36 {
                if event.modifierFlags.contains([.command, .shift]) {
                    self?.createTerminalFromNotch()
                } else {
                    self?.createNoteFromNotch()
                }
            }
        }

        // Local monitor: fires when the app IS focused — intercepts Enter before the text view
        enterKeyLocalMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 36 {
                if event.modifierFlags.contains([.command, .shift]) {
                    self?.createTerminalFromNotch()
                } else {
                    self?.createNoteFromNotch()
                }
                return nil  // Swallow the event so the text view doesn't get it
            }
            return event
        }
    }

    private func removeEnterKeyMonitor() {
        if let monitor = enterKeyGlobalMonitor {
            NSEvent.removeMonitor(monitor)
            enterKeyGlobalMonitor = nil
        }
        if let monitor = enterKeyLocalMonitor {
            NSEvent.removeMonitor(monitor)
            enterKeyLocalMonitor = nil
        }
    }

    private func createNoteFromNotch() {
        hideTrigger()
        WindowTracker.shared.createNewNote()
    }

    private func createTerminalFromNotch() {
        hideTrigger()
        WindowTracker.shared.createNewTerminal()
    }

    deinit {
        stop()
    }
}
