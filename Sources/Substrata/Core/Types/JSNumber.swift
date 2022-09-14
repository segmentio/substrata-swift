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

public class JSNumber: JSPrimitive {
    public override var value: JSConvertible? {
        return JSValueToNumber(context.ref, ref, nil)
    }
}

extension Double: JSConvertible {
    public func jsValue(context: JSContext) -> JSPrimitive {
        let ref = JSValueMakeNumber(context.ref, self)
        let n = JSNumber(context: context, ref: ref!)
        return n
    }
}

extension Int: JSConvertible {
    public func jsValue(context: JSContext) -> JSPrimitive {
        return Double(self).jsValue(context: context)
    }
}

extension UInt: JSConvertible {
    public func jsValue(context: JSContext) -> JSPrimitive {
        return Double(self).jsValue(context: context)
    }
}

extension Float: JSConvertible {
    public func jsValue(context: JSContext) -> JSPrimitive {
        return Double(self).jsValue(context: context)
    }
}

extension NSNumber: JSConvertible {
    public func jsValue(context: JSContext) -> JSPrimitive {
        return self.doubleValue.jsValue(context: context)
    }
}
