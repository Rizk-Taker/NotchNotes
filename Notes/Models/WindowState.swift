//
//  WindowState.swift
//  Notes
//
//  Created by Nick Rizk on 3/16/26.
//

import Foundation

class WindowState {
    var rootNode: PaneNode
    var focusedLeafID: UUID?

    init(document: NoteDocument) {
        let leaf = PaneLeaf(document: document)
        self.rootNode = .leaf(leaf)
        self.focusedLeafID = leaf.id
    }

    init(rootNode: PaneNode, focusedLeafID: UUID? = nil) {
        self.rootNode = rootNode
        self.focusedLeafID = focusedLeafID ?? rootNode.allLeaves.first?.id
    }

    var isSinglePane: Bool {
        if case .leaf = rootNode { return true }
        return false
    }

    var focusedLeaf: PaneLeaf? {
        guard let id = focusedLeafID else { return nil }
        return rootNode.allLeaves.first { $0.id == id }
    }

    var focusedDocument: NoteDocument? {
        return focusedLeaf?.document
    }

    /// Docks a new document next to the focused (or specified) leaf
    func dock(document: NoteDocument, onto targetLeafID: UUID, edge: DockEdge) {
        let newLeaf = PaneLeaf(document: document)
        let orientation: SplitOrientation = (edge == .left || edge == .right) ? .vertical : .horizontal
        let isNewFirst = (edge == .left || edge == .top)

        let first: PaneNode = isNewFirst ? .leaf(newLeaf) : rootNode.findLeafNode(id: targetLeafID)
        let second: PaneNode = isNewFirst ? rootNode.findLeafNode(id: targetLeafID) : .leaf(newLeaf)

        let newSplit = PaneSplit(orientation: orientation, first: first, second: second)
        rootNode = rootNode.replacing(leafID: targetLeafID, with: .split(newSplit))
        focusedLeafID = newLeaf.id
    }

    /// Docks a new terminal pane next to the specified leaf
    func dockTerminal(onto targetLeafID: UUID, edge: DockEdge) {
        let newLeaf = PaneLeaf(terminal: true)
        let orientation: SplitOrientation = (edge == .left || edge == .right) ? .vertical : .horizontal
        let isNewFirst = (edge == .left || edge == .top)

        let first: PaneNode = isNewFirst ? .leaf(newLeaf) : rootNode.findLeafNode(id: targetLeafID)
        let second: PaneNode = isNewFirst ? rootNode.findLeafNode(id: targetLeafID) : .leaf(newLeaf)

        let newSplit = PaneSplit(orientation: orientation, first: first, second: second)
        rootNode = rootNode.replacing(leafID: targetLeafID, with: .split(newSplit))
        focusedLeafID = newLeaf.id
    }

    /// Removes a pane from the tree
    func removePane(leafID: UUID) {
        if let newRoot = rootNode.removing(leafID: leafID) {
            rootNode = newRoot
            if focusedLeafID == leafID {
                focusedLeafID = rootNode.allLeaves.first?.id
            }
        }
    }
}

enum DockEdge {
    case top, bottom, left, right
}

// Helper to extract a leaf node by ID
extension PaneNode {
    func findLeafNode(id: UUID) -> PaneNode {
        switch self {
        case .leaf(let leaf):
            if leaf.id == id { return self }
            return self
        case .split(let split):
            if split.first.containsLeaf(id: id) {
                return split.first.findLeafNode(id: id)
            }
            return split.second.findLeafNode(id: id)
        }
    }

    /// Checks whether this node contains a leaf with the given ID
    func containsLeaf(id: UUID) -> Bool {
        return allLeaves.contains { $0.id == id }
    }
}
