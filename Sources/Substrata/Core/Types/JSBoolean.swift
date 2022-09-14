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

public class JSBoolean: JSPrimitive {
    public override var value: JSConvertible? {
        return JSValueToBoolean(context.ref, ref)
    }
}

extension Bool: JSConvertible {
    public func jsValue(context: JSContext) -> JSPrimitive {
        let ref = JSValueMakeBoolean(context.ref, self)
        let b = JSBoolean(context: context, ref: ref!)
        return b
    }
}
