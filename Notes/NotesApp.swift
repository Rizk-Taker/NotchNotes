//
//  NotesApp.swift
//  Notes
//
//  Created by Nick Rizk on 3/16/26.
//

import SwiftUI

@main
struct NotesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
