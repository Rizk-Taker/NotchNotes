//
//  NoteDocument.swift
//  Notes
//
//  Created by Nick Rizk on 3/16/26.
//

import Foundation

class NoteDocument: Identifiable {
    let id: UUID
    var fileURL: URL?
    var text: String
    var isDirty: Bool
    var lastModified: Date

    init(id: UUID = UUID(), fileURL: URL? = nil, text: String = "", isDirty: Bool = false) {
        self.id = id
        self.fileURL = fileURL
        self.text = text
        self.isDirty = isDirty
        self.lastModified = Date()
    }

    var displayName: String {
        if let url = fileURL {
            return url.deletingPathExtension().lastPathComponent
        }
        return "Untitled"
    }

    func textDidChange(_ newText: String) {
        text = newText
        isDirty = true
        lastModified = Date()
    }

    // MARK: - Save

    func save() {
        guard isDirty, let url = fileURL else { return }
        FileService.shared.writeFile(text: text, to: url)
        isDirty = false
    }

    func saveAs(url: URL) {
        fileURL = url
        FileService.shared.writeFile(text: text, to: url)
        isDirty = false
    }

    /// Creates a new file in the notes folder with a unique name.
    /// If no folder is configured, prompts the user to pick one first.
    func saveNew(completion: ((URL?) -> Void)? = nil) {
        if let folder = FolderSettings.shared.folderURL {
            let url = saveToFolder(folder)
            completion?(url)
        } else {
            // No folder set — ask the user to pick one, then save
            FolderSettings.shared.pickFolder { [weak self] selectedURL in
                guard let self, let folder = selectedURL else {
                    completion?(nil)
                    return
                }
                let url = self.saveToFolder(folder)
                completion?(url)
            }
        }
    }

    private func saveToFolder(_ folder: URL) -> URL {
        let ext = UserDefaults.standard.string(forKey: "fileExtension") ?? "md"
        let url = FileService.shared.uniqueFileURL(in: folder, extension: ext, text: text)
        fileURL = url
        FileService.shared.writeFile(text: text, to: url)
        isDirty = false
        return url
    }

    // MARK: - Load

    static func load(from url: URL) -> NoteDocument? {
        guard let text = FileService.shared.readFile(at: url) else { return nil }
        return NoteDocument(fileURL: url, text: text, isDirty: false)
    }


}
