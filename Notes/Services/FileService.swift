//
//  FileService.swift
//  Notes
//
//  Created by Nick Rizk on 3/16/26.
//

import Foundation

class FileService {
    static let shared = FileService()
    private init() {}

    func readFile(at url: URL) -> String? {
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            print("Failed to read file at \(url): \(error)")
            return nil
        }
    }

    func writeFile(text: String, to url: URL) {
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to write file at \(url): \(error)")
        }
    }

    /// Generates a unique file URL in the given folder, using the first 15 chars of the text as the name
    func uniqueFileURL(in folder: URL, extension ext: String, text: String) -> URL {
        let base = sanitizedFilename(from: text)
        var url = folder.appendingPathComponent("\(base).\(ext)")
        var counter = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = folder.appendingPathComponent("\(base) \(counter).\(ext)")
            counter += 1
        }
        return url
    }

    /// Uses the first non-empty line as the filename, stripped of markdown heading markers and unsafe chars.
    /// Caps at 60 chars to avoid filesystem issues. Falls back to "Untitled".
    private func sanitizedFilename(from text: String) -> String {
        let firstLine = text.components(separatedBy: .newlines)
            .first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) ?? ""
        // Strip leading markdown heading markers (# ## ### etc.)
        var cleaned = firstLine.trimmingCharacters(in: .whitespaces)
        while cleaned.hasPrefix("#") {
            cleaned = String(cleaned.dropFirst())
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)
        // Remove filesystem-unsafe characters
        cleaned = cleaned.replacingOccurrences(of: "[/:\\\\*?\"<>|]", with: "-", options: .regularExpression)
        // Collapse multiple dashes/spaces
        cleaned = cleaned.replacingOccurrences(of: "-{2,}", with: "-", options: .regularExpression)
        // Cap length
        cleaned = String(cleaned.prefix(60)).trimmingCharacters(in: .whitespacesAndNewlines)
        // Remove trailing dots/dashes
        while cleaned.hasSuffix(".") || cleaned.hasSuffix("-") {
            cleaned = String(cleaned.dropLast())
        }
        return cleaned.isEmpty ? "Untitled" : cleaned
    }
}
