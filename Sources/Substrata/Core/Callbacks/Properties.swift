//
//  File.swift
//  
//
//  Created by Brandon Sneed on 6/2/22.
//

import Foundation

#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

public typealias JSPropertyGetCallback = (_ context: JSContext, _ this: JSObject?) -> JSPrimitive?
public typealias JSPropertySetCallback = (_ context: JSContext, _ this: JSObject?, _ value: JSPrimitive?) -> Bool

// MARK: - C-style callbacks

internal func property_getter(
    _ ctx: JSContextRef?,
    _ object: JSObjectRef?,
    _ propertyName: JSStringRef?,
    _ exception: UnsafeMutablePointer<JSValueRef?>?
) -> JSValueRef? {
    guard let propertyName = propertyName else {
        return nil
    }
    
    // TODO: handle exception here
    
    var result: JSValueRef? = nil

    let info = JSObjectGetPrivate(object).assumingMemoryBound(to: JSExportInfo.self)
    guard let context = info.pointee.context else { return nil }
    let props = info.pointee.addedProperties
    guard let propName = String.from(jsString: propertyName) else { return nil }
    if let property = props[propName] {
        if let getter = property.getter, let objRef = object {
            let obj = JSObject(context: context, ref: objRef)
            result = getter(context, obj)?.ref
        }
    }
    
    return result
}

internal func property_setter(
    _ ctx: JSContextRef?,
    _ object: JSObjectRef?,
    _ propertyName: JSStringRef?,
    _ value: JSValueRef?,
    _ exception: UnsafeMutablePointer<JSValueRef?>?
) -> Bool {
    guard let propertyName = propertyName else {
        return false
    }
    
    // TODO: handle exception here
    
    var result: Bool = false

    let info = JSObjectGetPrivate(object).assumingMemoryBound(to: JSExportInfo.self)
    guard let context = info.pointee.context else { return false }
    let props = info.pointee.addedProperties
    guard let propName = String.from(jsString: propertyName) else { return false }
    if let property = props[propName] {
        if let setter = property.setter, let objRef = object {
            let obj = JSObject(context: context, ref: objRef)
            let value = JSPrimitive.construct(from: value, context: context)
            result = setter(context, obj, value)
        }
    }
    
    return result
}

