//
//  BoundingVolumeHierarchy.swift
//  BezierKit
//
//  Created by Holmes Futrell on 8/6/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import CoreGraphics

private func left(_ index: Int) -> Int {
    return 2 &* index &+ 1 // left child of complete binary tree is always 2*i+1
}

private func right(_ index: Int) -> Int {
    return 2 &* index &+ 2 // right child of complete binary tree is always 2*i+2
}

final internal class BVH {
    
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
            let elementIndex = BVH.leafNodeIndexToElementIndex(nodeIndex, elementCount: self.elementCount, lastRowIndex: lastRowIndex)
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
    
    func visit(callback: (BVHNode, Int) -> Bool) {
        let elementCount = self.elementCount
        let lastRowIdnex = self.lastRowIndex
        let boxes = self.boundingBoxes
        func visit(index: Int, depth: Int, callback: (BVHNode, Int) -> Bool) {
            let leaf = BVH.isLeaf(index, elementCount: elementCount)
            let nodeType: BVHNode.NodeType = leaf ? .leaf(elementIndex: BVH.leafNodeIndexToElementIndex(index, elementCount: elementCount, lastRowIndex: lastRowIndex)) : .internal
            let node = BVHNode(boundingBox: boxes[index], type: nodeType)
            guard callback(node, depth) == true else {
                return
            }
            if leaf == false {
                let nextDepth = depth + 1
                visit(index: left(index), depth: nextDepth, callback: callback)
                visit(index: right(index), depth: nextDepth, callback: callback)
            }
        }
        visit(index: 0, depth: 0, callback: callback)
    }

    func boundingBox(forElementIndex index: Int) -> BoundingBox {
        return self.boundingBoxes[BVH.elementIndexToNodeIndex(index, elementCount: self.elementCount, lastRowIndex: self.lastRowIndex)]
    }

    func intersects(callback: (Int, Int) -> Void) {
        self.intersects(node: self, callback: callback)
    }
    
    func intersects(node other: BVH, callback: (Int, Int) -> Void) {
        let elementCount1 = self.elementCount
        let elementCount2 = other.elementCount
        let boxes1 = self.boundingBoxes
        let boxes2 = other.boundingBoxes
        let lastRowIndex1 = self.lastRowIndex
        let lastRowIndex2 = other.lastRowIndex
        func intersects(index: Int, callback: (Int, Int) -> Void) {
            if BVH.isLeaf(index, elementCount: elementCount1) { // if it's a leaf node
                let elementIndex = BVH.leafNodeIndexToElementIndex(index, elementCount: elementCount1, lastRowIndex: lastRowIndex1)
                callback(elementIndex, elementIndex)
            }
            else {
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
            let leaf1: Bool = BVH.isLeaf(index1, elementCount: elementCount1)
            let leaf2: Bool = BVH.isLeaf(index2, elementCount: elementCount2)
            if leaf1, leaf2 {
                let elementIndex1 = BVH.leafNodeIndexToElementIndex(index1, elementCount: elementCount1, lastRowIndex: lastRowIndex1)
                let elementIndex2 = BVH.leafNodeIndexToElementIndex(index2, elementCount: elementCount2, lastRowIndex: lastRowIndex2)
                callback(elementIndex1, elementIndex2)
            }
            else if leaf1 {
                intersects(index1: index1, index2: left(index2), callback: callback)
                intersects(index1: index1, index2: right(index2), callback: callback)
            }
            else if leaf2 {
                intersects(index1: left(index1), index2: index2, callback: callback)
                intersects(index1: right(index1), index2: index2, callback: callback)
            }
            else {
                intersects(index1: left(index1), index2: left(index2), callback: callback)
                intersects(index1: left(index1), index2: right(index2), callback: callback)
                intersects(index1: right(index1), index2: left(index2), callback: callback)
                intersects(index1: right(index1), index2: right(index2), callback: callback)
            }
        }
        if (other === self) {
            intersects(index: 0, callback: callback)
        }
        else {
            intersects(index1: 0, index2: 0, callback: callback)
        }
    }
}

internal struct BVHNode {
    let boundingBox: BoundingBox
    let type: NodeType
    enum NodeType {
        case leaf(elementIndex: Int)
        case `internal`
    }
    fileprivate init(boundingBox: BoundingBox, type: NodeType) {
        self.type = type
        self.boundingBox = boundingBox
    }
}
