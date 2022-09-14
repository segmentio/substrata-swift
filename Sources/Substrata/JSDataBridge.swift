//
//  JSDataBridge.swift
//
//
//  Created by Brandon Sneed on 4/11/22.
//

import Foundation

#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

/**
 Provides a mechanism to move data between JS/Native.
 
 Useful in instances where one just needs to send over some data
 without necessarily calling into javascript itself.
 */
public class JSDataBridge: JavascriptDataBridge {
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
            return engine.syncRunEngine { [weak self] in
                guard let self = self else { return nil }
                // get the bridge first.
                if let bridge = self.engine?.context[Self.dataBridgeKey].typed(JSObject.self) {
                    // now get the value for the key
                    return bridge[key].value
                }
                // it doesn't have what we were looking for.
                return nil
            }
        }
        
        set(value) {
            guard let engine = engine else { return }
            engine.syncRunEngine { [weak self] in
                guard let self = self else { return nil }
                // get the bridge first.
                if let bridge = self.engine?.context[Self.dataBridgeKey].typed(JSObject.self) {
                    // now set the value for the key
                    if let v = value {
                        bridge[key] = v.jsValue(context: engine.context)
                    } else {
                        // value is nil, so remove the key by setting it to undefined.
                        bridge[key] = engine.context.undefined
                    }
                }
                // return nil to satisfy requirements for this sync run call.
                return nil
            }
        }
    }
}
