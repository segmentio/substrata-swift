//
//  DataBridge.swift
//  
//
//  Created by Brandon Sneed on 1/12/23.
//

import Foundation

/**
 Provides a mechanism to move data between JS/Native.
 
 Useful in instances where one just needs to send over some data
 without necessarily calling into javascript itself.
 */
public class JSDataBridge {
    static let dataBridgeKey = "dataBridge"
    weak var engine: JSEngine?
    
    init() { }
    
    /**
     Get/set values in the data bridge.
     */
    public subscript(keyPath: String) -> JSConvertible? {
        get {
            return value(for: keyPath)
        }
        
        set(value) {
            setValue(for: keyPath, value: value)
        }
    }
    
    public func value(for keyPath: String) -> JSConvertible? {
        guard let engine = engine else { return nil }
        let v = engine.value(for: "\(Self.dataBridgeKey).\(keyPath)")
        return v
    }
    
    @discardableResult
    public func setValue(for keyPath: String, value: JSConvertible?) -> Bool {
        guard let engine = engine else { return false }
        return engine.setValue(for: "\(Self.dataBridgeKey).\(keyPath)", value: value)
    }
}

extension JSDataBridge {
    internal func setEngine(_ engine: JSEngine) {
        // we already have one fool!
        if self.engine != nil { return }
        self.engine = engine
        engine.evaluate(script: "var \(JSDataBridge.dataBridgeKey) = {};")
    }
}
