//
//  FolderSettings.swift
//  Notes
//
//  Created by Nick Rizk on 3/16/26.
//

import AppKit

class FolderSettings {
    static let shared = FolderSettings()

    private static let bookmarkKey = "notesFolderBookmark"

    var folderURL: URL?

    private init() {
        folderURL = restoreBookmark()
    }

    // MARK: - Bookmark Persistence

    private func restoreBookmark() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: Self.bookmarkKey) else { return nil }
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                // Re-save bookmark
                saveBookmark(for: url)
            }
            _ = url.startAccessingSecurityScopedResource()
            return url
        } catch {
            print("Failed to restore bookmark: \(error)")
            return nil
        }
    }

    private func saveBookmark(for url: URL) {
        do {
            let data = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(data, forKey: Self.bookmarkKey)
        } catch {
            print("Failed to save bookmark: \(error)")
        }
    }

    // MARK: - Folder Picker

    func pickFolder(completion: ((URL?) -> Void)? = nil) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose where Notes saves your notes"
        panel.prompt = "Select Folder"
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else {
                completion?(nil)
                return
            }
            self?.setFolder(url)
            completion?(url)
        }
    }

    func setFolder(_ url: URL) {
        // Stop accessing old resource
        folderURL?.stopAccessingSecurityScopedResource()

        saveBookmark(for: url)
        _ = url.startAccessingSecurityScopedResource()
        folderURL = url
    }
}
