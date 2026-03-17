//
//  OnboardingWindowController.swift
//  Notes
//
//  Created by Nick Rizk on 3/16/26.
//

import AppKit
import SwiftUI

class OnboardingWindowController: NSWindowController {

    static let shared = OnboardingWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to NotchPad"
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showOnboarding() {
        window?.contentView = NSHostingView(rootView: OnboardingView(page: .setup, dismiss: { [weak self] in
            self?.window?.close()
        }))
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showHowToUse() {
        window?.contentView = NSHostingView(rootView: OnboardingView(page: .instructions, dismiss: { [weak self] in
            self?.window?.close()
        }))
        window?.title = "How to Use"
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - SwiftUI Onboarding View

enum OnboardingPage {
    case setup
    case instructions
}

struct OnboardingView: View {
    @State var page: OnboardingPage
    let dismiss: () -> Void

    var body: some View {
        Group {
            switch page {
            case .setup:
                SetupPage(onNext: { page = .instructions })
            case .instructions:
                InstructionsPage(onDone: dismiss)
            }
        }
        .frame(width: 520, height: 560)
    }
}

// MARK: - Page 1: Setup

struct SetupPage: View {
    let onNext: () -> Void
    @AppStorage("fileExtension") private var fileExtension: String = "md"
    @AppStorage("autosaveEnabled") private var autosaveEnabled: Bool = false
    @State private var folderPath: String = FolderSettings.shared.folderURL?.path ?? ""

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 40)

            Text("Welcome to NotchPad")
                .font(.system(size: 24, weight: .bold))

            Text("Let's get you set up")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Spacer().frame(height: 32)

            VStack(alignment: .leading, spacing: 20) {
                // Folder picker
                VStack(alignment: .leading, spacing: 6) {
                    Text("Where should notes be saved?")
                        .font(.system(size: 13, weight: .medium))

                    HStack {
                        Text(folderPath.isEmpty ? "No folder selected" : folderPath)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button("Choose Folder…") {
                            FolderSettings.shared.pickFolder { url in
                                folderPath = url?.path ?? ""
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)

                    Text("This can be any folder — iCloud Drive, an Obsidian vault, Dropbox, or a local folder. Your notes are plain text files you own.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }

                // File format
                VStack(alignment: .leading, spacing: 6) {
                    Text("Default file format")
                        .font(.system(size: 13, weight: .medium))

                    Picker("", selection: $fileExtension) {
                        Text(".md — Markdown (works with Obsidian, iA Writer, etc.)").tag("md")
                        Text(".txt — Plain Text").tag("txt")
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }

                // Auto-save
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Auto-save notes", isOn: $autosaveEnabled)
                        .font(.system(size: 13, weight: .medium))
                    Text("When enabled, notes auto-save 500ms after you stop typing.")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 40)

            Spacer()

            HStack {
                Spacer()
                Button(action: onNext) {
                    Text("Next")
                        .frame(width: 80)
                }
                .keyboardShortcut(.return, modifiers: [])
                .controlSize(.large)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 24)
        }
    }
}

// MARK: - Page 2: Instructions

struct InstructionsPage: View {
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 32)

            Text("How to Use")
                .font(.system(size: 24, weight: .bold))

            Spacer().frame(height: 24)

            VStack(alignment: .leading, spacing: 20) {
                // Creating Notes
                sectionBlock(title: "Creating Notes") {
                    instructionRow(keys: "Notch + Enter", description: "Hover the notch, press Enter")
                    instructionRow(keys: "⌘ N", description: "New note from anywhere")
                }

                // Splitting Panes
                sectionBlock(title: "Note Panes") {
                    instructionRow(keys: "⌘ D", description: "Split vertically (side by side)")
                    instructionRow(keys: "⇧⌘ D", description: "Split horizontally (stacked)")
                }

                // Terminal Panes
                sectionBlock(title: "Terminal Panes") {
                    instructionRow(keys: "Notch + ⇧⌘ Enter", description: "New terminal window from notch")
                    instructionRow(keys: "⌘ T", description: "Terminal split vertical")
                    instructionRow(keys: "⇧⌘ T", description: "Terminal split horizontal")
                }

                // Navigation
                sectionBlock(title: "Navigation") {
                    instructionRow(keys: "⌥⌘ Arrows", description: "Move focus between panes")
                    instructionRow(keys: "⌘ W", description: "Close pane")
                }

                // Saving
                sectionBlock(title: "Saving") {
                    instructionRow(keys: "⌘ S", description: "Save — filename from first line")
                    instructionRow(keys: "⇧⌘ S", description: "Save As — choose location")
                }
            }
            .padding(.horizontal, 40)

            Spacer()

            HStack {
                Spacer()
                Button(action: onDone) {
                    Text("Get Started")
                        .frame(width: 100)
                }
                .keyboardShortcut(.return, modifiers: [])
                .controlSize(.large)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 24)
        }
    }

    private func sectionBlock<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.primary)
                .textCase(.uppercase)
                .tracking(0.5)
            content()
        }
    }

    private func instructionRow(keys: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(keys)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .frame(width: 120, alignment: .trailing)
                .foregroundStyle(.primary)

            Text(description)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
