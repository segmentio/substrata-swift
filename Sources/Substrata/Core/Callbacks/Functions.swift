//
//  File.swift
//  
//
//  Created by Brandon Sneed on 5/31/22.
//

import Foundation

#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif


// MARK: - C-style callbacks

internal func function_finalize(_ object: JSObjectRef?) -> Void {
    let info = JSObjectGetPrivate(object).assumingMemoryBound(to: JSFunctionInfo.self)
    info.deinitialize(count: 1)
    info.deallocate()
}

internal func function_callback(
    _ ctx: JSContextRef?,
    _ object: JSObjectRef?,
    _ this: JSObjectRef?,
    _ argumentCount: Int,
    _ arguments: UnsafePointer<JSValueRef?>?,
    _ exception: UnsafeMutablePointer<JSValueRef?>?
) -> JSValueRef? {
    let info = JSObjectGetPrivate(object).assumingMemoryBound(to: JSFunctionInfo.self)
    guard let context = info.pointee.context else { return nil }
    
    let this = JSPrimitive.construct(from: this, context: context) as? JSObject
    let arguments = (0..<argumentCount).map { JSPrimitive.construct(from: arguments![$0]!, context: context) }
    let result = info.pointee.callback(context, this, arguments)
    return result.ref
}

internal func function_instanceof(
    _ ctx: JSContextRef?,
    _ constructor: JSObjectRef?,
    _ possibleInstance: JSValueRef?,
    _ exception: UnsafeMutablePointer<JSValueRef?>?
) -> Bool {
    let info = JSObjectGetPrivate(constructor).assumingMemoryBound(to: JSFunctionInfo.self)
    guard let context = info.pointee.context else { return false }
    let prototype_0 = JSObjectGetPrototype(context.ref, constructor)
    let prototype_1 = JSObjectGetPrototype(context.ref, possibleInstance)
    return JSValueIsStrictEqual(context.ref, prototype_0, prototype_1)
}
