//
//  File.swift
//  
//
//  Created by Brandon Sneed on 6/9/22.
//

import Foundation

internal class ReentrantQueue {
    var queue: DispatchQueue
    var keyValue: String
    var queueKey: DispatchSpecificKey<String>
    
    init(label: String, key: String) {
        self.queueKey = DispatchSpecificKey<String>()
        self.queue = DispatchQueue(label: label)
        self.keyValue = key
        self.queue.setSpecific(key: self.queueKey, value: self.keyValue)
    }
    
    var isRunningOnQueue: Bool {
        return queue.getSpecific(key: queueKey) == keyValue
    }
    
    func reentrantSync<T>(execute work: () throws -> T) rethrows -> T {
        if isRunningOnQueue {
            return try work()
        } else {
            return try queue.sync(execute: work)
        }
    }
}
