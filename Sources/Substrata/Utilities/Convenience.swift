//
//  Convenience.swift
//  
//
//  Created by Brandon Sneed on 1/22/23.
//

import Foundation
#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJavaScriptCore
#endif

@inlinable
internal func jsTyped(_ value: JSConvertible?, context: JSContextRef) -> JSValueRef? {
    let v = value?.jsValue(context: context)
    if v != nil {
        return v
    }
    return JSValueMakeUndefined(context)
}

internal func isNativeAndNotASubclass(value: JSValueRef?, context: JSContextRef) -> Bool {
    guard JSObjectGetPrivate(value) != nil else { return false }
    let script = JSStringRefWrapper(value: """
        this.constructor.name === Object.getPrototypeOf(Object.getPrototypeOf(this)).constructor.name
    """)
    if let valueRef = JSEvaluateScript(context, script.ref, value, nil, 0, nil) {
        guard let b = Bool.from(jsValue: valueRef, context: context) else { return false }
        return b
    }
    return false
}
