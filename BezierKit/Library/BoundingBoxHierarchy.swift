//
//  BoundingBoxHierarchy.swift
//  BezierKit
//
//  Created by Holmes Futrell on 8/6/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import CoreGraphics

/// returns the power of two greater than or equal to a given value
internal func roundUpPowerOfTwo(_ value: Int) -> Int {
    var result = 1
    while result < value {
        result = result << 1
    }
    return result
}

/// left child node index by the formula 2*index+1
private func left(_ index: Int) -> Int {
    return 2 &* index &+ 1
}

/// right child node index by the formula 2*index+2
private func right(_ index: Int) -> Int {
    return 2 &* index &+ 2
}

/// parent node index index by the formula (index-1) / 2
private func parent(_ index: Int) -> Int {
    return (index &- 1) / 2
}

/// a strict (complete and full) binary tree representing a hierarchy of bounding boxes for a list of path elements
final internal class BoundingBoxHierarchy {

    internal enum NodeType: Equatable {
        case leaf(elementIndex: Int)
        case `internal`(startingElementIndex: Int, endingElementIndex: Int)
    }

    internal struct Node: Equatable {
        let boundingBox: BoundingBox
        let type: NodeType
        init(boundingBox: BoundingBox, type: NodeType) {
            self.type = type
            self.boundingBox = boundingBox
        }
    }

    private let boundingBoxes: UnsafePointer<BoundingBox>
    private let lastRowIndex: Int
    private let elementCount: Int

    internal static func leafNodeIndexToElementIndex(_ nodeIndex: Int, elementCount: Int, lastRowIndex: Int) -> Int {
        assert(isLeaf(nodeIndex, elementCount: elementCount))
        var elementIndex = nodeIndex - lastRowIndex
        if elementIndex < 0 {
            elementIndex += elementCount
        }
        return elementIndex
    }

    internal static func elementIndexToNodeIndex(_ elementIndex: Int, elementCount: Int, lastRowIndex: Int) -> Int {
        assert(elementIndex >= 0 && elementIndex < elementCount)
        var nodeIndex = elementIndex + lastRowIndex
        if nodeIndex >= 2 * elementCount - 1 {
            nodeIndex -= elementCount
        }
        return nodeIndex
    }

    private static func isLeaf(_ index: Int, elementCount: Int) -> Bool {
        return index >= elementCount-1
    }

    var boundingBox: BoundingBox {
        return self.boundingBoxes[0]
    }

    init(boxes elementBoxes: [BoundingBox]) {
        assert(!elementBoxes.isEmpty)
        self.elementCount = elementBoxes.count
        let inodeCount = self.elementCount-1 // in complete binary tree the number of inodes (internal nodes) is one fewer than the leafs
        // compute `lastRowIndex` the index of the first leaf node in the bottom row of the tree
        var lastRowIndex = 0
        while lastRowIndex < inodeCount {
            lastRowIndex = left(lastRowIndex)
        }
        self.lastRowIndex = lastRowIndex
        // compute bounding boxes
        let boxes = UnsafeMutablePointer<BoundingBox>.allocate(capacity: self.elementCount + inodeCount)
        for i in 0..<self.elementCount {
            let nodeIndex = i+inodeCount
            let elementIndex = BoundingBoxHierarchy.leafNodeIndexToElementIndex(nodeIndex, elementCount: self.elementCount, lastRowIndex: lastRowIndex)
            boxes[nodeIndex] = elementBoxes[elementIndex]
        }
        for i in stride(from: inodeCount-1, through: 0, by: -1) {
            boxes[i] = BoundingBox(first: boxes[left(i)], second: boxes[right(i)])
        }
        self.boundingBoxes = UnsafePointer<BoundingBox>(boxes)
    }

    deinit {
        self.boundingBoxes.deallocate()
    }

    func visit(callback: (Node, Int) -> Bool) {
        let elementCount = self.elementCount
        let lastRowIndex = self.lastRowIndex
        let nodeCount    = 2 &* elementCount &- 1
        let boxes = self.boundingBoxes
        func visitHelper(index: Int, depth: Int, maxLeafsInSubtree: Int, callback: (Node, Int) -> Bool) {
            let leaf = BoundingBoxHierarchy.isLeaf(index, elementCount: elementCount)
            let nodeType: NodeType
            if leaf {
                nodeType = .leaf(elementIndex: BoundingBoxHierarchy.leafNodeIndexToElementIndex(index, elementCount: elementCount, lastRowIndex: lastRowIndex))
            } else {
                var startingIndex   = maxLeafsInSubtree * ( index + 1 ) - 1
                var endingIndex     = startingIndex + maxLeafsInSubtree - 1
                if endingIndex >= nodeCount {
                    endingIndex = parent(endingIndex)
                }
                if startingIndex >= nodeCount {
                    startingIndex = parent(startingIndex)
                }
                let endingElementIndex = BoundingBoxHierarchy.leafNodeIndexToElementIndex(endingIndex, elementCount: elementCount, lastRowIndex: lastRowIndex)
                let startingElementIndex = BoundingBoxHierarchy.leafNodeIndexToElementIndex(startingIndex, elementCount: elementCount, lastRowIndex: lastRowIndex)
                nodeType = .internal(startingElementIndex: startingElementIndex, endingElementIndex: endingElementIndex)
            }
            let node = Node(boundingBox: boxes[index], type: nodeType)
            guard callback(node, depth) == true else {
                return
            }
            if leaf == false {
                let nextDepth = depth + 1
                let nextMaxLeafsInSubtree = maxLeafsInSubtree / 2
                visitHelper(index: left(index), depth: nextDepth, maxLeafsInSubtree: nextMaxLeafsInSubtree, callback: callback)
                visitHelper(index: right(index), depth: nextDepth, maxLeafsInSubtree: nextMaxLeafsInSubtree, callback: callback)
            }
        }
        // maxLeafsInSubtree: refers to the number of leaf nodes in the subtree were the bottom level of the tree full
        visitHelper(index: 0, depth: 0, maxLeafsInSubtree: roundUpPowerOfTwo(elementCount), callback: callback)
    }

    func boundingBox(forElementIndex index: Int) -> BoundingBox {
        return self.boundingBoxes[BoundingBoxHierarchy.elementIndexToNodeIndex(index, elementCount: self.elementCount, lastRowIndex: self.lastRowIndex)]
    }

    func enumerateSelfIntersections(callback: (Int, Int) -> Void) {
        self.enumerateIntersections(with: self, callback: callback)
    }

    func enumerateIntersections(with other: BoundingBoxHierarchy, callback: (Int, Int) -> Void) {
        let elementCount1 = self.elementCount
        let elementCount2 = other.elementCount
        let boxes1 = self.boundingBoxes
        let boxes2 = other.boundingBoxes
        let lastRowIndex1 = self.lastRowIndex
        let lastRowIndex2 = other.lastRowIndex
        func intersects(index: Int, callback: (Int, Int) -> Void) {
            if BoundingBoxHierarchy.isLeaf(index, elementCount: elementCount1) { // if it's a leaf node
                let elementIndex = BoundingBoxHierarchy.leafNodeIndexToElementIndex(index, elementCount: elementCount1, lastRowIndex: lastRowIndex1)
                callback(elementIndex, elementIndex)
            } else {
                let l = left(index)
                let r = right(index)
                intersects(index: l, callback: callback)
                intersects(index1: l, index2: r, callback: callback)
                intersects(index: r, callback: callback)
            }
        }
        func intersects(index1: Int, index2: Int, callback: (Int, Int) -> Void) {
            guard boxes1[index1].overlaps(boxes2[index2]) else {
                return // nothing to do
            }
            let leaf1: Bool = BoundingBoxHierarchy.isLeaf(index1, elementCount: elementCount1)
            let leaf2: Bool = BoundingBoxHierarchy.isLeaf(index2, elementCount: elementCount2)
            if leaf1, leaf2 {
                let elementIndex1 = BoundingBoxHierarchy.leafNodeIndexToElementIndex(index1, elementCount: elementCount1, lastRowIndex: lastRowIndex1)
                let elementIndex2 = BoundingBoxHierarchy.leafNodeIndexToElementIndex(index2, elementCount: elementCount2, lastRowIndex: lastRowIndex2)
                callback(elementIndex1, elementIndex2)
            } else if leaf1 {
                intersects(index1: index1, index2: left(index2), callback: callback)
                intersects(index1: index1, index2: right(index2), callback: callback)
            } else if leaf2 {
                intersects(index1: left(index1), index2: index2, callback: callback)
                intersects(index1: right(index1), index2: index2, callback: callback)
            } else {
                intersects(index1: left(index1), index2: left(index2), callback: callback)
                intersects(index1: left(index1), index2: right(index2), callback: callback)
                intersects(index1: right(index1), index2: left(index2), callback: callback)
                intersects(index1: right(index1), index2: right(index2), callback: callback)
            }
        }
        if other === self {
            intersects(index: 0, callback: callback)
        } else {
            intersects(index1: 0, index2: 0, callback: callback)
        }
    }
}
