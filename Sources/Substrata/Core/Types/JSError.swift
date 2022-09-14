//
//  File.swift
//  
//
//  Created by Brandon Sneed on 6/8/22.
//

import Foundation

#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

public class JSError: JSObject {
    public convenience init(context: JSContext, message: String) {
        let args = [JSString(context: context, value: message)]
        let error = JSObjectMakeError(context.ref, 1, args.map { $0.ref }, nil)!
        self.init(context: context, ref: error)
    }
    
    public override func jsDescription() -> String? {
        return """
        Javascript Error:
            Error: (\(name), \(message))
            Cause: \(cause ?? "unknown")
            Stack: \(stack ?? "unavailable")
        """
    }
    
    public var cause: String? {
        return self["cause"].value(String.self)
    }
    
    public var stack: String? {
        return self["stack"].value(String.self)
    }
    
    public var message: String {
        return self["message"].value(String.self) ?? "unknown"
    }
    
    public var name: String {
        return self["name"].value(String.self) ?? "unspecified"
    }
}

