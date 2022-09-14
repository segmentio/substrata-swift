//
//  File.swift
//  
//
//  Created by Brandon Sneed on 5/26/22.
//

import Foundation

#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

public typealias JSFunctionCallback = (_ context: JSContext, _ this: JSObject?, _ params: [JSPrimitive]) -> JSPrimitive

public struct JSFunctionInfo: JSConvertible {
    public func jsValue(context: JSContext) -> JSPrimitive {
        let function = JSFunction(context: context, callback: callback)
        return function
    }
    
    weak var context: JSContext?
    let callback: JSFunctionCallback
}

public class JSFunction: JSObject {
    convenience public init(context: JSContext, callback: @escaping JSFunctionCallback) {
        let info: UnsafeMutablePointer<JSFunctionInfo> = .allocate(capacity: 1)
        info.initialize(to: JSFunctionInfo(context: context, callback: callback))
        
        var def = JSClassDefinition()
        def.finalize = function_finalize
        def.callAsFunction = function_callback
        def.hasInstance = function_instanceof
        
        let _class = JSClassCreate(&def)
        defer { JSClassRelease(_class) }
        
        self.init(context: context, ref: JSObjectMake(context.ref, _class, info))
    }

    public override var value: JSConvertible? {
        /*if JSObjectGetPrivate(ref) != nil {
            let info = JSObjectGetPrivate(ref).assumingMemoryBound(to: JSFunctionInfo.self)
            return info.pointee
        }*/
        return nil
    }
    
    public override func jsDescription() -> String? {
        if value == nil {
            return call(method: "toString", params: []).value(String.self)
        }
        return "[native function]"
    }
}

