//
//  SettingsWindowController.swift
//  Notes
//
//  Created by Nick Rizk on 3/16/26.
//

import AppKit
import SwiftUI

class SettingsWindowController: NSWindowController {

    static let shared = SettingsWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView())

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showSettings() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @AppStorage("fileExtension") private var fileExtension: String = "md"
    @AppStorage("autosaveEnabled") private var autosaveEnabled: Bool = false
    @State private var folderPath: String = FolderSettings.shared.folderURL?.path ?? "No folder selected"

    var body: some View {
        Form {
            Section {
                Button("How to Use NotchPad") {
                    OnboardingWindowController.shared.showHowToUse()
                }
                .font(.headline)
            }

            Section("Notes Folder") {
                HStack {
                    Text(folderPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Change…") {
                        FolderSettings.shared.pickFolder { url in
                            folderPath = url?.path ?? "No folder selected"
                        }
                    }
                }
            }

            Section("Saving") {
                Toggle("Auto-save", isOn: $autosaveEnabled)
                Text("When enabled, notes auto-save 500ms after you stop typing.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Section("File Format") {
                Picker("", selection: $fileExtension) {
                    Text(".md (Markdown)").tag("md")
                    Text(".txt (Plain Text)").tag("txt")
                }
                .pickerStyle(.radioGroup)
                .labelsHidden()
            }
        }
        .formStyle(.grouped)
        .frame(width: 450, height: 420)
    }
}
