//
//  BezierPath.swift
//  BezierKit
//
//  Created by Holmes Futrell on 7/31/18.
//  Copyright © 2018 Holmes Futrell. All rights reserved.
//

import CoreGraphics
import Foundation

@objc(BezierKitPathFillRule) public enum PathFillRule: NSInteger {
    case winding=0, evenOdd
}

internal func windingCountImpliesContainment(_ count: Int, using rule: PathFillRule) -> Bool {
    switch rule {
    case .winding:
        return count != 0
    case .evenOdd:
        return count % 2 != 0
    }
}

@objc(BezierKitPath) public class Path: NSObject, NSCoding {
    
    private class PathApplierFunctionContext {
        var currentPoint: CGPoint? = nil
        var subpathStartPoint: CGPoint? = nil
        
        var currentSubpathPoints: [CGPoint] = []
        var currentSubpathOrders: [Int] = []
        
        var components: [PathComponent] = []
        func finishUp() {
            if currentSubpathPoints.isEmpty == false {
                components.append(PathComponent(points: currentSubpathPoints, orders: currentSubpathOrders))
                currentSubpathPoints = []
                currentSubpathOrders = []
            }
        }
    }
    
    @objc(CGPath) public lazy var cgPath: CGPath = {
        let mutablePath = CGMutablePath()
        self.subpaths.forEach {
            mutablePath.addPath($0.cgPath)
        }
        return mutablePath.copy()!
    }()
    
    @objc public var isEmpty: Bool {
        return self.subpaths.isEmpty // components are not allowed to be empty
    }
    
    public lazy var boundingBox: BoundingBox = {
        return self.subpaths.reduce(BoundingBox.empty) {
            BoundingBox(first: $0, second: $1.boundingBox)
        }
    }()
    
    public let subpaths: [PathComponent]
    
    @objc(point:isWithinDistanceOfBoundary:) public func pointIsWithinDistanceOfBoundary(point p: CGPoint, distance d: CGFloat) -> Bool {
        return self.subpaths.contains {
            $0.pointIsWithinDistanceOfBoundary(point: p, distance: d)
        }
    }
    
    @objc(intersectsWithThreshold:) public func intersects(threshold: CGFloat = BezierKit.defaultIntersectionThreshold) -> [PathIntersection] {
        var intersections: [PathIntersection] = []
        for i in 0..<self.subpaths.count {
            for j in i..<self.subpaths.count {
                let componentIntersectionToPathIntersection = {(componentIntersection: PathComponentIntersection) -> PathIntersection in
                    PathIntersection(componentIntersection: componentIntersection, componentIndex1: i, componentIndex2: j)
                }
                if i == j {
                    intersections += self.subpaths[i].intersects(threshold: threshold).map(componentIntersectionToPathIntersection)
                }
                else {
                    intersections += self.subpaths[i].intersects(component: self.subpaths[j], threshold: threshold).map(componentIntersectionToPathIntersection)
                }
            }
        }
        return intersections
    }
    
    @objc(intersectsWithPath:threshold:) public func intersects(path other: Path, threshold: CGFloat = BezierKit.defaultIntersectionThreshold) -> [PathIntersection] {
        guard self.boundingBox.overlaps(other.boundingBox) else {
            return []
        }
        var intersections: [PathIntersection] = []
        for i in 0..<self.subpaths.count {
            for j in 0..<other.subpaths.count {
                let componentIntersectionToPathIntersection = {(componentIntersection: PathComponentIntersection) -> PathIntersection in
                    PathIntersection(componentIntersection: componentIntersection, componentIndex1: i, componentIndex2: j)
                }
                let s1 = self.subpaths[i]
                let s2 = other.subpaths[j]
                let componentIntersections: [PathComponentIntersection] = s1.intersects(component: s2, threshold: threshold)
                intersections += componentIntersections.map(componentIntersectionToPathIntersection)
            }
        }
        return intersections
    }
    
    @objc public convenience override init() {
        self.init(subpaths: [])
    }
    
    required public init(subpaths: [PathComponent]) {
        self.subpaths = subpaths
    }
    
    @objc(initWithCGPath:) convenience public init(cgPath: CGPath) {
        var context = PathApplierFunctionContext()
        func applierFunction(_ ctx: UnsafeMutableRawPointer?, _ element: UnsafePointer<CGPathElement>) {
            guard let context = ctx?.assumingMemoryBound(to: PathApplierFunctionContext.self).pointee else {
                fatalError("unexpected applierFunction context")
            }
            let points: UnsafeMutablePointer<CGPoint> = element.pointee.points
            switch element.pointee.type {
            case .moveToPoint:
                if context.currentSubpathOrders.isEmpty == false {
                    context.components.append(PathComponent(points: context.currentSubpathPoints, orders: context.currentSubpathOrders))
                }
                context.subpathStartPoint = points[0]
                context.currentSubpathOrders = []
                context.currentSubpathPoints = [points[0]]
                context.currentPoint = points[0]
            case .addLineToPoint:
                context.currentSubpathOrders.append(1)
                context.currentSubpathPoints.append(points[0])
                context.currentPoint = points[0]
            case .addQuadCurveToPoint:
                context.currentSubpathOrders.append(2)
                context.currentSubpathPoints.append(points[0])
                context.currentSubpathPoints.append(points[1])
                context.currentPoint = points[1]
            case .addCurveToPoint:
                context.currentSubpathOrders.append(3)
                context.currentSubpathPoints.append(points[0])
                context.currentSubpathPoints.append(points[1])
                context.currentSubpathPoints.append(points[2])
                context.currentPoint = points[2]
            case .closeSubpath:
                if context.currentPoint != context.subpathStartPoint {
                    context.currentSubpathOrders.append(1)
                    context.currentSubpathPoints.append(context.subpathStartPoint!)
                }
                if context.currentSubpathOrders.isEmpty == false {
                    context.components.append(PathComponent(points: context.currentSubpathPoints, orders: context.currentSubpathOrders))
                }
                context.currentPoint = context.subpathStartPoint!
                context.currentSubpathPoints = []
                context.currentSubpathOrders = []
            }
        }
        let rawContextPointer = UnsafeMutableRawPointer(&context).bindMemory(to: PathApplierFunctionContext.self, capacity: 1)
        cgPath.apply(info: rawContextPointer, function: applierFunction)
        context.finishUp()
        
        self.init(subpaths: context.components)
    }
    
    // MARK: - NSCoding
    // (cannot be put in extension because init?(coder:) is a designated initializer)
    
    public func encode(with aCoder: NSCoder) {
        aCoder.encode(self.subpaths)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        guard let array = aDecoder.decodeObject() as? Array<PathComponent> else {
            return nil
        }
        self.subpaths = array
    }
    
    // MARK: -
    
    override public func isEqual(_ object: Any?) -> Bool {
        // override is needed because NSObject implementation of isEqual(_:) uses pointer equality
        guard let otherPath = object as? Path else {
            return false
        }
        return self.subpaths == otherPath.subpaths
    }
    
    // MARK: - vector boolean operations
    
    public func point(at location: IndexedPathLocation) -> CGPoint {
        return self.elementAtComponentIndex(location.componentIndex, elementIndex: location.elementIndex).compute(location.t)
    }
    
    internal func elementAtComponentIndex(_ componentIndex: Int, elementIndex: Int) -> BezierCurve {
        return self.subpaths[componentIndex].element(at: elementIndex)
    }
    
    internal func windingCount(_ point: CGPoint, ignoring: PathComponent? = nil) -> Int {
        let windingCount = self.subpaths.reduce(0) {
            if $1 !== ignoring {
                return $0 + $1.windingCount(at: point)
            }
            else {
                return $0
            }
        }
        return windingCount
    }

    @objc(containsPoint:usingRule:) public func contains(_ point: CGPoint, using rule: PathFillRule = .winding) -> Bool {
        let count = self.windingCount(point)
        return windingCountImpliesContainment(count, using: rule)
    }

    @objc(containsPath:) public func contains(_ other: Path) -> Bool {
        // first, check that each component of `other` starts inside self
        for component in other.subpaths {
            let p = component.startingPoint
            guard self.contains(p) else {
                return false
            }
        }
        // next, for each intersection (if there are any) check that we stay inside the path
        // TODO: use enumeration over intersections so we don't have to necessarily have to find each one
        // TODO: make this work with winding fill rule and intersections that don't cross (suggestion, use AugmentedGraph)
        return self.intersects(path: other).isEmpty
    }
    
    @objc(offsetWithDistance:) public func offset(distance d: CGFloat) -> Path {
        return Path(subpaths: self.subpaths.map {
            $0.offset(distance: d)
        })
    }
    
    private func performBooleanOperation(_ operation: BooleanPathOperation, withPath other: Path, threshold: CGFloat) -> Path? {
        let intersections = self.intersects(path: other, threshold: threshold)
        let augmentedGraph = AugmentedGraph(path1: self, path2: other, intersections: intersections)
        return augmentedGraph.booleanOperation(operation)
    }
    
    @objc(subtractingPath:threshold:) public func subtracting(_ other: Path, threshold: CGFloat=BezierKit.defaultIntersectionThreshold) -> Path? {
        return self.performBooleanOperation(.difference, withPath: other.reversed(), threshold: threshold)
    }
    
    @objc(unionedWithPath:threshold:) public func `union`(_ other: Path, threshold: CGFloat=BezierKit.defaultIntersectionThreshold) -> Path? {
        guard self.isEmpty == false else {
            return other
        }
        guard other.isEmpty == false else {
            return self
        }
        return self.performBooleanOperation(.union, withPath: other, threshold: threshold)
    }
    
    @objc(intersectedWithPath:threshold:) public func intersecting(_ other: Path, threshold: CGFloat=BezierKit.defaultIntersectionThreshold) -> Path? {
        return self.performBooleanOperation(.intersection, withPath: other, threshold: threshold)
    }
    
    @objc(crossingsRemovedWithThreshold:) public func crossingsRemoved(threshold: CGFloat=BezierKit.defaultIntersectionThreshold) -> Path? {
        let intersections = self.intersects(threshold: threshold)
        let augmentedGraph = AugmentedGraph(path1: self, path2: self, intersections: intersections)
        return augmentedGraph.booleanOperation(.removeCrossings)
    }

    @objc public func disjointSubpaths() -> [Path] {
        
        var paths: [Path] = []
        var subpathWindingCounts: [Path: Int] = [:]
        let subpathsAsPaths = self.subpaths.map { Path(subpaths: [$0]) }
        for subpath in subpathsAsPaths {
            let windingCount = self.windingCount(subpath.subpaths[0].startingPoint, ignoring: subpath.subpaths[0])
            if windingCount == 0 {
                paths.append(subpath)
            }
            subpathWindingCounts[subpath] = windingCount
        }
        
        var pathsWithHoles: [Path: Path] = [:]
        for path in paths {
            pathsWithHoles[path] = path
        }
        
        for subpath in subpathsAsPaths {
            guard subpathWindingCounts[subpath] != 0 else {
                continue
            }
            var owner: Path? = nil
            for path in paths {
                guard path.contains(subpath) else {
                    continue
                }
                if owner != nil {
                    if owner!.contains(path) {
                        owner = path
                    }
                }
                else {
                    owner = path
                }
            }
            if let owner = owner {
                pathsWithHoles[owner] = Path(subpaths: pathsWithHoles[owner]!.subpaths + subpath.subpaths)
            }
        }
        return Array(pathsWithHoles.values)
    }
}

@objc extension Path: Transformable {
    @objc(copyUsingTransform:) public func copy(using t: CGAffineTransform) -> Self {
        return type(of: self).init(subpaths: self.subpaths.map { $0.copy(using: t)})
    }
}

@objc extension Path: Reversible {
    public func reversed() -> Self {
        return type(of: self).init(subpaths: self.subpaths.map { $0.reversed() })
    }
}

@objc(BezierKitPathPosition) public class IndexedPathLocation: NSObject {
    internal let componentIndex: Int
    internal let elementIndex: Int
    internal let t: CGFloat
    init(componentIndex: Int, elementIndex: Int, t: CGFloat) {
        self.componentIndex = componentIndex
        self.elementIndex = elementIndex
        self.t = t
    }
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? IndexedPathLocation else {
            return false
        }
        return self.componentIndex == other.componentIndex && self.elementIndex == other.elementIndex && self.t == other.t
    }
}

@objc(BezierKitPathIntersection) public class PathIntersection: NSObject {
    public let indexedPathLocation1, indexedPathLocation2: IndexedPathLocation
    internal init(indexedPathLocation1: IndexedPathLocation, indexedPathLocation2: IndexedPathLocation) {
        self.indexedPathLocation1 = indexedPathLocation1
        self.indexedPathLocation2 = indexedPathLocation2
    }
    fileprivate init(componentIntersection: PathComponentIntersection, componentIndex1: Int, componentIndex2: Int) {
        self.indexedPathLocation1 = IndexedPathLocation(componentIndex: componentIndex1,
                                                        elementIndex: componentIntersection.indexedComponentLocation1.elementIndex,
                                                        t: componentIntersection.indexedComponentLocation1.t)
        self.indexedPathLocation2 = IndexedPathLocation(componentIndex: componentIndex2,
                                                        elementIndex: componentIntersection.indexedComponentLocation2.elementIndex,
                                                        t: componentIntersection.indexedComponentLocation2.t)

    }
    public override func isEqual(_ object: Any?) -> Bool {
        guard let other = object as? PathIntersection else {
            return false
        }
        return self.indexedPathLocation1 == other.indexedPathLocation1 && self.indexedPathLocation2 == other.indexedPathLocation2
    }
}

fileprivate extension Data {
    mutating func appendNativeValue<U>(_ value: U) {
        var temp = value
        withUnsafePointer(to: &temp) { (ptr: UnsafePointer<U>) in
            let bytesSize = MemoryLayout<U>.size
            let bytes: UnsafePointer<UInt8> = UnsafeRawPointer(ptr).bindMemory(to: UInt8.self, capacity: bytesSize)
            self.append(bytes, count: bytesSize)
        }
    }
}

fileprivate extension UnsafePointer where Pointee == UInt8 {
    func readNativeValue<T>(_ value: inout T) -> UnsafePointer<UInt8> {
        let size = MemoryLayout<T>.size
        let ptr = UnsafeRawPointer(self).bindMemory(to: T.self, capacity: 1)
        value = ptr.pointee
        return self + size
    }
    func readNativeValues<T>(to array: inout [T], count: Int) -> UnsafePointer<UInt8> {
        let size = count * MemoryLayout<T>.size
        let pointer: UnsafePointer<T> = UnsafeRawPointer(self).bindMemory(to: T.self, capacity: count)
        let bufferPointer = UnsafeBufferPointer<T>(start: pointer, count: count)
        array.append(contentsOf: bufferPointer)
        return self + size
    }
}

public extension Path {

    private typealias MagicNumberType = UInt32
    static private let magicNumberVersion1: MagicNumberType = 1223013157 // just a random number that helps us identify if the data is OK and saved in compatible version

    static private let startComponentCommand: UInt8 = 0
    
    internal enum PathDataError: Error {
        case magicNumberUnsupportedOrWrong
        case insufficientDataBytes
    }
    
    public convenience init?(data: Data) {

        var subpaths: [PathComponent] = []

        var commandCount: UInt32 = 0
        
        var commands: [UInt8] = []
        //var error: PathDataError? = nil
        var success = true
        let _ = data.withUnsafeBytes { (dataBytes: UnsafePointer<UInt8>) -> Void in
            var ptr = dataBytes
            //var bytesRemaining = data.count
            
            // check the magic number
            var magic: MagicNumberType = MagicNumberType.max
            ptr = ptr.readNativeValue(&magic)
            guard magic == Path.magicNumberVersion1 else {
                //error = .magicNumberUnsupportedOrWrong
                success = false
                return
            }
            
            ptr = ptr.readNativeValue(&commandCount)
            ptr = ptr.readNativeValues(to: &commands, count: Int(commandCount))
            
            var currentPoints: [CGPoint] = []
            var currentOrders: [Int] = []
            
            for command in commands {
                
                var pointsToRead = 1
                if command == Path.startComponentCommand {
                    if currentOrders.isEmpty == false {
                        subpaths.append(PathComponent(points: currentPoints, orders: currentOrders))
                        currentPoints = []
                        currentOrders = []
                    }
                }
                else {
                    pointsToRead = Int(command)
                    currentOrders.append(pointsToRead)
                }
                for _ in 0..<pointsToRead {
                    var x: Double = 0
                    var y: Double = 0
                    ptr = ptr.readNativeValue(&x)
                    ptr = ptr.readNativeValue(&y)
                    let point = CGPoint(x: CGFloat(x), y: CGFloat(y))
                    currentPoints.append(point)
                }
            }
            if currentOrders.isEmpty == false {
                subpaths.append(PathComponent(points: currentPoints, orders: currentOrders))
            }
        }
        if success == false {
            return nil
        }
        self.init(subpaths: subpaths)
    }

    public var data: Data {
        // one command to start each subpath (aside from the first subpath), plus one command for each element in the path
        assert(MemoryLayout<MagicNumberType>.size == 4)
        assert(MemoryLayout<UInt32>.size == 4)
        assert(MemoryLayout<Float64>.size == 8)

        let expectedPointsCount = 2 * self.subpaths.reduce(0) { $0 + $1.points.count }
        let expectedCommandsCount = self.subpaths.reduce(0) { $0 + $1.elementCount } + (self.subpaths.count)

        // compile the data into a single buffer we can easily write
        var commands: [UInt8] = []
        var points: [Double] = []
        points.reserveCapacity(expectedPointsCount)
        for subpath in self.subpaths {
            points += subpath.points.flatMap { [Float64($0.x), Float64($0.y)] }
            commands.append(0)
            commands += subpath.orders.map { UInt8($0) }
        }
        assert(expectedPointsCount == points.count)
        assert(expectedCommandsCount == commands.count)

        var result = Data()
        let expectedBytesCount = MemoryLayout<MagicNumberType>.size + MemoryLayout<UInt32>.size + MemoryLayout<UInt8>.size * commands.count + MemoryLayout<Float64>.size * points.count
        result.reserveCapacity(expectedBytesCount)
        // write the magicNumber
        result.appendNativeValue(Path.magicNumberVersion1)
        // write the commands count
        result.appendNativeValue(UInt32(commands.count))
        result.append(contentsOf: commands)
        // write the points
        points.withUnsafeBufferPointer { buffer in
            result.append(buffer)
        }
        assert(result.count == expectedBytesCount, "wrong number of bytes! expected \(expectedBytesCount) got \(result.count)")
        return result
    }
}
