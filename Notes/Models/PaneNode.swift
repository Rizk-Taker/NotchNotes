//
//  PaneNode.swift
//  Notes
//
//  Created by Nick Rizk on 3/16/26.
//

import Foundation
import CoreGraphics

indirect enum PaneNode: Identifiable {
    case leaf(PaneLeaf)
    case split(PaneSplit)

    var id: UUID {
        switch self {
        case .leaf(let leaf): return leaf.id
        case .split(let split): return split.id
        }
    }

    /// Returns all leaf documents in this node tree
    var allLeaves: [PaneLeaf] {
        switch self {
        case .leaf(let leaf):
            return [leaf]
        case .split(let split):
            return split.first.allLeaves + split.second.allLeaves
        }
    }

    /// Finds the leaf containing the given document ID
    func findLeaf(documentID: UUID) -> PaneLeaf? {
        switch self {
        case .leaf(let leaf):
            return leaf.document?.id == documentID ? leaf : nil
        case .split(let split):
            return split.first.findLeaf(documentID: documentID)
                ?? split.second.findLeaf(documentID: documentID)
        }
    }

    /// Replaces a leaf node with a new node (used for docking)
    func replacing(leafID: UUID, with newNode: PaneNode) -> PaneNode {
        switch self {
        case .leaf(let leaf):
            if leaf.id == leafID {
                return newNode
            }
            return self
        case .split(let split):
            return .split(PaneSplit(
                id: split.id,
                orientation: split.orientation,
                ratio: split.ratio,
                first: split.first.replacing(leafID: leafID, with: newNode),
                second: split.second.replacing(leafID: leafID, with: newNode)
            ))
        }
    }

    /// Removes a leaf node, collapsing the tree as needed.
    /// Returns nil if the whole tree should be removed.
    func removing(leafID: UUID) -> PaneNode? {
        switch self {
        case .leaf(let leaf):
            return leaf.id == leafID ? nil : self
        case .split(let split):
            let newFirst = split.first.removing(leafID: leafID)
            let newSecond = split.second.removing(leafID: leafID)
            if let first = newFirst, let second = newSecond {
                return .split(PaneSplit(
                    id: split.id,
                    orientation: split.orientation,
                    ratio: split.ratio,
                    first: first,
                    second: second
                ))
            }
            // One side was removed — collapse to the remaining side
            return newFirst ?? newSecond
        }
    }
}

enum PaneContent {
    case editor(NoteDocument)
    case terminal
}

struct PaneLeaf: Identifiable {
    let id: UUID
    var content: PaneContent

    init(id: UUID = UUID(), document: NoteDocument) {
        self.id = id
        self.content = .editor(document)
    }

    init(id: UUID = UUID(), terminal: Bool) {
        self.id = id
        self.content = .terminal
    }

    /// Convenience accessor — returns nil for terminal panes
    var document: NoteDocument? {
        if case .editor(let doc) = content { return doc }
        return nil
    }

    var isTerminal: Bool {
        if case .terminal = content { return true }
        return false
    }
}

struct PaneSplit: Identifiable {
    let id: UUID
    var orientation: SplitOrientation
    var ratio: CGFloat
    var first: PaneNode
    var second: PaneNode

    init(id: UUID = UUID(), orientation: SplitOrientation, ratio: CGFloat = 0.5, first: PaneNode, second: PaneNode) {
        self.id = id
        self.orientation = orientation
        self.ratio = ratio
        self.first = first
        self.second = second
    }
}

enum SplitOrientation {
    case horizontal  // top/bottom
    case vertical    // left/right
}

// MARK: - Layout Geometry

extension PaneNode {
    /// Computes the layout rectangle of every leaf node given the available bounds.
    /// Uses the same geometry as PaneSplitView: for a vertical split with ratio `r`
    /// in width `W`, first child gets `r * (W - dividerThickness)`, divider gets
    /// `dividerThickness`, second child gets the remainder.
    func layoutRects(in bounds: CGRect, dividerThickness: CGFloat = 3) -> [UUID: CGRect] {
        switch self {
        case .leaf(let leaf):
            return [leaf.id: bounds]
        case .split(let split):
            let (firstBounds, secondBounds) = splitBounds(
                bounds: bounds,
                orientation: split.orientation,
                ratio: split.ratio,
                dividerThickness: dividerThickness
            )
            var rects = split.first.layoutRects(in: firstBounds, dividerThickness: dividerThickness)
            let secondRects = split.second.layoutRects(in: secondBounds, dividerThickness: dividerThickness)
            for (id, rect) in secondRects {
                rects[id] = rect
            }
            return rects
        }
    }

    private func splitBounds(
        bounds: CGRect,
        orientation: SplitOrientation,
        ratio: CGFloat,
        dividerThickness: CGFloat
    ) -> (CGRect, CGRect) {
        switch orientation {
        case .vertical:
            let firstWidth = ratio * (bounds.width - dividerThickness)
            let secondWidth = (1 - ratio) * (bounds.width - dividerThickness)
            let first = CGRect(x: bounds.minX, y: bounds.minY,
                             width: firstWidth, height: bounds.height)
            let second = CGRect(x: bounds.minX + firstWidth + dividerThickness, y: bounds.minY,
                              width: secondWidth, height: bounds.height)
            return (first, second)
        case .horizontal:
            let firstHeight = ratio * (bounds.height - dividerThickness)
            let secondHeight = (1 - ratio) * (bounds.height - dividerThickness)
            let first = CGRect(x: bounds.minX, y: bounds.minY + secondHeight + dividerThickness,
                             width: bounds.width, height: firstHeight)
            let second = CGRect(x: bounds.minX, y: bounds.minY,
                              width: bounds.width, height: secondHeight)
            return (first, second)
        }
    }

    /// Returns a new tree with the split ratio updated for the given split ID.
    func updatingRatio(splitID: UUID, newRatio: CGFloat) -> PaneNode {
        switch self {
        case .leaf:
            return self
        case .split(let split):
            if split.id == splitID {
                return .split(PaneSplit(
                    id: split.id,
                    orientation: split.orientation,
                    ratio: newRatio,
                    first: split.first,
                    second: split.second
                ))
            }
            return .split(PaneSplit(
                id: split.id,
                orientation: split.orientation,
                ratio: split.ratio,
                first: split.first.updatingRatio(splitID: splitID, newRatio: newRatio),
                second: split.second.updatingRatio(splitID: splitID, newRatio: newRatio)
            ))
        }
    }
}
