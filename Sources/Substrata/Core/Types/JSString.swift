//
//  File.swift
//  
//
//  Created by Brandon Sneed on 5/25/22.
//

import Foundation

#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

public class JSString: JSPrimitive {
    convenience public init(context: JSContext, value: String) {
        let str = JSStringRefWrapper(value: value)
        let valueRef = JSValueMakeString(context.ref, str.ref)!
        self.init(context: context, ref: valueRef)
    }
    
    public override var value: JSConvertible? {
        //return String.from(jsString: ref)
        return String.from(jsString: JSValueToStringCopy(context.ref, ref, nil))
    }
}

extension String: JSConvertible {
    public func jsValue(context: JSContext) -> JSPrimitive {
        let s = JSString(context: context, value: self)
        return s
    }
}

extension NSString: JSConvertible {
    public func jsValue(context: JSContext) -> JSPrimitive {
        let s = JSString(context: context, value: self as String)
        return s
    }
}

// MARK: String helper stuff

internal class JSStringRefWrapper {
    var ref: JSStringRef
    
    init(value: String) {
        ref = value.withCString(JSStringCreateWithUTF8CString)!
    }
    
    init(value: JSStringRef) {
        ref = value
        JSStringRetain(ref)
    }
    
    deinit {
        JSStringRelease(ref)
    }
}



