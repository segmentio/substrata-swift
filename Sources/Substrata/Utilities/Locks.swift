//
//  File.swift
//  
//
//  Created by Brandon Sneed on 2/4/24.
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
}

internal struct Lock {
    private let lock = NSLock()
    
    @discardableResult
    func perform<T>(closure: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return closure()
    }
}
