//
//  File.swift
//
//
//  Created by Brandon Sneed on 6/9/22.
//

import Foundation

internal struct RecursiveLock {
    private let lock = NSRecursiveLock()

    @discardableResult
    func perform<T>(closure: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return closure()
    }

    @discardableResult
    func perform<T>(closure: () throws -> T ) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        return try closure()
    }
}
