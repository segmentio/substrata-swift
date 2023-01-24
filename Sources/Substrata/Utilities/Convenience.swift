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

@inlinable
internal func hasPrivateData(value: JSValueRef?) -> Bool {
    let ptr = JSObjectGetPrivate(value)
    if ptr != nil { return true }
    return false
}
