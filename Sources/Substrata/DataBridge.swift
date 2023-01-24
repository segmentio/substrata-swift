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
    
    init(engine: JSEngine) {
        self.engine = engine
    }
    
    /**
     Get/set values in the data bridge.
     */
    public subscript(key: String) -> JSConvertible? {
        get {
            guard let engine = engine else { return nil }
            let v = engine.value(for: "\(Self.dataBridgeKey).\(key)")
            return v
        }
        
        set(value) {
            guard let engine = engine else { return }
            engine.setValue(for: "\(Self.dataBridgeKey).\(key)", value: value)
        }
    }
}
