//
//  BoundingVolumeHierarchy.swift
//  BezierKit
//
//  Created by Holmes Futrell on 8/6/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import CoreGraphics

private class BVHConstructionContext {
    
    private let table: UnsafeMutablePointer<CGFloat>
    private let tableRowLength: Int
    
    func boundingBoxArea(_ i: Int,_ j: Int) -> CGFloat {
        return table[i * tableRowLength + j]
    }
    
    init(objects: [BoundingBoxProtocol]) {
        
        // table[i][j] stores the bounding box of objects i...j, for j<i it is the union of i..<count union 0..<=j
        
        assert(objects.count > 0)
        
        let objectBoundingBoxes = objects.map { $0.boundingBox }
        
        tableRowLength = objects.count
        table = UnsafeMutablePointer<CGFloat>.allocate(capacity: tableRowLength * tableRowLength)
        for i in 0..<objects.count {
            
            let row: UnsafeMutablePointer<CGFloat> = table + i * objects.count
            
            var prev = objectBoundingBoxes[i]
            row[i] = prev.area
            
            for j in i+1..<objects.count {
                prev.union(objectBoundingBoxes[j])
                row[j] = prev.area
            }
            if i > 0 {
                prev.union(objectBoundingBoxes[0])
                row[0] = prev.area
            }
            if i > 1 {
                for j in 1..<i {
                    prev.union(objectBoundingBoxes[j])
                    row[j] = prev.area
                }
            }
        }
        
        // check the results
        
//        for i in 0..<objects.count {
//            for j in 0..<objects.count {
//                var expected = BoundingBox.empty
//
//                for ip in 0..<objects.count {
//                    if (ip >= i && ip <= j) || (j < i && (ip <= j || ip >= i) ) {
//                        expected = BoundingBox(first: expected, second: objects[ip].boundingBox)
//                    }
//                }
//                assert(expected == table[i][j])
//
//            }
//        }
        
    }
    
    deinit {
        table.deallocate()
    }
    
}

internal class BVHNode {
    let boundingBox: BoundingBox
    let nodeType: NodeType
    enum NodeType {
        case leaf(object: BoundingBoxProtocol)
        case `internal`(list: [BVHNode])
    }
    func visit(callback: (BVHNode, Int) -> Void, currentDepth depth: Int) {
        callback(self, depth)
        if case let .`internal`(list: list) = self.nodeType {
            list.forEach {
                $0.visit(callback: callback, currentDepth: depth+1)
            }
        }
    }
    fileprivate init(objects: ArraySlice<BoundingBoxProtocol>, context: BVHConstructionContext) {
      
        assert(objects.isEmpty == false, "unexpectedly empty array slice!")
        
        if objects.count == 1 {
            self.nodeType = .leaf(object: objects.first!)
            self.boundingBox = objects.first!.boundingBox
            return
        }
        
        // determine where to split the node between left and right
        
        var split = objects.startIndex+1
        var minArea = context.boundingBoxArea(objects.startIndex, split-1) + context.boundingBoxArea(split,objects.endIndex-1)
        
        if objects.count > 2 {
            for j in objects.startIndex+2..<objects.endIndex {
                let area = context.boundingBoxArea(objects.startIndex, j-1) + context.boundingBoxArea(j,objects.endIndex-1)
                if area < minArea {
                    split = j
                    minArea = area
                }
            }
        }
        
        // now that we've found the optimal split, recurse to compute children
        
        let left = BVHNode(objects: objects[objects.startIndex..<split], context: context)
        let right = BVHNode(objects: objects[split..<objects.endIndex], context: context)
        
        let boundingBox = BoundingBox(first: left.boundingBox, second: right.boundingBox)
        
        self.boundingBox = boundingBox
    
        
        let list: [BVHNode] = [left, right].reduce([BVHNode]()) { nextResult, node in
            if case let .`internal`(nodeChildren) = node.nodeType {
                if ( (1.0 - node.boundingBox.area / boundingBox.area) * CGFloat(nodeChildren.count)) < 1.0 { // surface area heuristic to determine flattening
                    return nextResult + nodeChildren
                }
            }
            return nextResult + [node]
        }
        self.nodeType = .internal(list: list)

    }
    func intersects(node other: BVHNode, callback: (BoundingBoxProtocol, BoundingBoxProtocol) -> Void) {
        
        guard self.boundingBox.overlaps(other.boundingBox) else {
            return // nothing to do
        }
        
        if case let .leaf(object1) = self.nodeType {
            if case let .leaf(object2) = other.nodeType {
                callback(object1, object2)
            }
            else if case let .internal(list: list2) = other.nodeType {
                list2.forEach {
                    self.intersects(node: $0, callback: callback)
                }
            }
        }
        else if case let .`internal`(list: list1) = self.nodeType {
            if case .leaf(_) = other.nodeType {
                list1.forEach {
                    $0.intersects(node: other, callback: callback)
                }
            }
            else if case let .`internal`(list: list2) = other.nodeType {
                list1.forEach { node1 in
                    list2.forEach { node2 in
                        node1.intersects(node: node2, callback: callback)
                    }
                }
            }
        }
    }
}

internal class BoundingVolumeHierarchy {
    private let root: BVHNode
    
    init(objects: [BoundingBoxProtocol]) {
        
        let context = BVHConstructionContext(objects: objects)
        
        // first we need to get the objects in an optimal order
        
        var minArea: CGFloat = context.boundingBoxArea(0,0) + context.boundingBoxArea(1, objects.count-1)
        var bestIndex = (0, 0)
        
        for i in 0..<objects.count {
            for j in i..<objects.count {
                var area = context.boundingBoxArea(i, j)
                if ( i > 0) {
                    area += context.boundingBoxArea(0, i)
                }
                if ( j+1 < objects.count ) {
                    area += context.boundingBoxArea(j+1, objects.count-1)
                }
                if area < minArea {
                    minArea = area
                    bestIndex = (i,j)
                }
            }
        }
        
        var reordered: [BoundingBoxProtocol] = []
        if bestIndex.1 < bestIndex.0 {
            reordered = [BoundingBoxProtocol](objects[0...bestIndex.1]) + [BoundingBoxProtocol](objects[bestIndex.0..<objects.count])
        }
        else {
            reordered = [BoundingBoxProtocol](objects[bestIndex.0...bestIndex.1]) + [BoundingBoxProtocol](objects[(bestIndex.1+1)..<objects.count]) + [BoundingBoxProtocol](objects[0..<bestIndex.0])
        }
        let context2 = BVHConstructionContext(objects: [BoundingBoxProtocol](reordered))
        self.root = BVHNode(objects: reordered[0..<reordered.count], context: context2)

//        var maxChildren = 0
//        var maxDepth = 0
//        self.visit { node, depth in
//            guard case let .`internal`(nodeChildren) = node.nodeType else {
//                return
//            }
//            if nodeChildren.count > maxChildren { // surface area heuristic to determine flattening
//                maxChildren = nodeChildren.count
//            }
//            if depth > maxDepth {
//                maxDepth = depth
//            }
//        }
//
//        print("max children = \(maxChildren)")
//        print("max depth = \(maxDepth)")

    }
    
    func intersects(boundingVolumeHierarchy other: BoundingVolumeHierarchy, callback: (BoundingBoxProtocol, BoundingBoxProtocol) -> Void) {
        self.root.intersects(node: other.root, callback: callback)
    }
    
    func visit(callback: (BVHNode, Int) -> Void) {
        self.root.visit(callback: callback, currentDepth: 0)
    }
    
}
