//
//  Path+Data.swift
//  BezierKit
//
//  Created by Holmes Futrell on 3/15/19.
//  Copyright © 2019 Holmes Futrell. All rights reserved.
//

import Foundation
import CoreGraphics

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

fileprivate extension InputStream {
    func readNativeValue<T>(_ value: UnsafeMutablePointer<T>) -> Bool {
        let size = MemoryLayout<T>.size
        return value.withMemoryRebound(to: UInt8.self, capacity: size) {
            self.read($0, maxLength: size) == size
        }
    }
    func appendNativeValues<T>(to array: inout [T], count: Int) -> Bool {
        guard count > 0 else { return true }
        let size = count * MemoryLayout<T>.stride
        let buffer = UnsafeMutableBufferPointer<UInt8>.allocate(capacity: size)
        defer { buffer.deallocate() }
        guard let pointer = buffer.baseAddress else { return false }
        let bytesRead = self.read(pointer, maxLength: size)
        guard bytesRead == size else { return false }
        array.append(contentsOf: UnsafeRawBufferPointer(buffer).bindMemory(to: T.self))
        return true
    }
}

private struct SerializationTypes {
    typealias MagicNumber   = UInt32
    typealias CommandCount  = UInt32
    typealias Command       = UInt8
    typealias Coordinate    = Float64
}

@objc public extension Path {

    private struct SerializationConstants {
        static let magicNumberVersion1: SerializationTypes.MagicNumber = 1223013157 // just a random number that helps us identify if the data is OK and saved in compatible version
        static let startComponentCommand: SerializationTypes.Command = 0
    }

    @objc(initWithData:) convenience init?(data: Data) {

        var components: [PathComponent] = []

        var commandCount: SerializationTypes.CommandCount = 0
        var commands: [SerializationTypes.Command] = []

        let stream = InputStream(data: data)
        stream.open()

        // check the magic number
        var magic = SerializationTypes.MagicNumber.max
        guard stream.readNativeValue(&magic) else { return nil }
        guard magic == SerializationConstants.magicNumberVersion1 else {
            return nil
        }
        guard stream.readNativeValue(&commandCount) else { return nil }
        guard stream.appendNativeValues(to: &commands, count: Int(commandCount)) else { return nil }

        // read the commands and coordinates
        var currentPoints: [CGPoint] = []
        var currentOrders: [Int] = []
        for i in 0..<commands.count {
            let command = commands[i]
            var pointsToRead = Int(command)
            if command == SerializationConstants.startComponentCommand {
                if currentPoints.isEmpty || currentOrders.isEmpty == false {
                    pointsToRead = 1
                }
                if currentPoints.isEmpty == false {
                    if currentOrders.isEmpty {
                        assert(currentPoints.count == 1)
                        currentOrders.append(0)
                    }
                    components.append(PathComponent(points: currentPoints, orders: currentOrders))
                    currentPoints = []
                    currentOrders = []
                }
            } else {
                currentOrders.append(pointsToRead)
            }
            for _ in 0..<pointsToRead {
                var x: SerializationTypes.Coordinate = 0
                var y: SerializationTypes.Coordinate = 0
                guard stream.readNativeValue(&x) else { return nil }
                guard stream.readNativeValue(&y) else { return nil }
                let point = CGPoint(x: CGFloat(x), y: CGFloat(y))
                currentPoints.append(point)
            }
        }
        if currentOrders.isEmpty == false {
            components.append(PathComponent(points: currentPoints, orders: currentOrders))
        }
        self.init(components: components)
    }

    var data: Data {

        let expectedCoordinatesCount = 2 * self.components.reduce(0) { $0 + $1.points.count }
        let expectedCommandsCount = self.components.reduce(0) { $0 + $1.numberOfElements } + self.components.count

        // compile the data into a format we can easily serialize
        var commands: [SerializationTypes.Command] = []
        commands.reserveCapacity(expectedCommandsCount)
        var coordinates: [SerializationTypes.Coordinate] = []
        coordinates.reserveCapacity(expectedCoordinatesCount)
        for component in self.components {
            coordinates += component.points.flatMap { [SerializationTypes.Coordinate($0.x), SerializationTypes.Coordinate($0.y)] }
            commands.append(SerializationConstants.startComponentCommand)
            commands += component.orders.map { SerializationTypes.Command($0) }
        }
        assert(expectedCoordinatesCount == coordinates.count)
        assert(expectedCommandsCount == commands.count)

        // serialize the data to object of type `Data`
        var result = Data()
        let expectedBytesCount = MemoryLayout<SerializationTypes.MagicNumber>.size + MemoryLayout<SerializationTypes.CommandCount>.size + MemoryLayout<SerializationTypes.Command>.size * commands.count + MemoryLayout<SerializationTypes.Coordinate>.size * coordinates.count
        result.reserveCapacity(expectedBytesCount)
        // write the magicNumber
        result.appendNativeValue(SerializationConstants.magicNumberVersion1)
        // write the commands count
        result.appendNativeValue(SerializationTypes.CommandCount(commands.count))
        // write the commands
        commands.withUnsafeBufferPointer { result.append($0) }
        // write the points
        coordinates.withUnsafeBufferPointer { result.append($0) }

        return result
    }
}
