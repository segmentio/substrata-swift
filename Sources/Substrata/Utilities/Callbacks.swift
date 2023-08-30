//
//  Callbacks.swift
//  
//
//  Created by Brandon Sneed on 1/10/23.
//

import Foundation
#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJavaScriptCore
#endif

internal struct JSClassInfo {
    let classRef: JSClassRef
    let nativeType: JSExport.Type
}

/**
 This variable holds critical info for any instantiated objects.  There's no way to
 connect an instance to a native type while preserving the prototype, as the prototype is
 only maintained when using JSObjectMakeConstructor, which disables use of JSObjectSetPrivate until
 an actual instance is made.  The entries in this list are removed in the `class_finalize` method.
 
 This *IS* a global thing .. but lookup/cleanup will be isolated to a given JSEngine instance.
 */
internal var JSExportBookkeeping = [JSObjectRef: JSClassInfo]()


internal func genericClassCreate(_ type: JSExport.Type, name: String) -> JSClassRef {
    var classDefinition = JSClassDefinition()
    let classRef: JSClassRef = name.withCString { cName in
        classDefinition.className = cName
        classDefinition.attributes = JSClassAttributes(kJSClassAttributeNone)
        classDefinition.finalize = class_finalize
        return JSClassCreate(&classDefinition)
    }
    return classRef
}

internal func genericFunctionCreate(_ function: JSFunctionDefinition) -> JSClassRef {
    var classDefinition = JSClassDefinition()
    classDefinition.callAsFunction = function_callback
    classDefinition.finalize = function_finalize
    return JSClassCreate(&classDefinition)
}

internal func updatePrototype(object: JSObjectRef?, context: JSContextRef, properties: [String: JSProperty]?, methods: [String: JSFunctionDefinition]?)
{
    guard let object else { return }
    var prototype = JSObjectGetPrototype(context, object)
    if prototype == nil {
        prototype = JSObjectMake(context, nil, nil)
    }
    
    if let methods {
        for (key, value) in methods {
            let name = JSStringRefWrapper(value: key)
            let functionRef = genericFunctionCreate(value)
            let info: UnsafeMutablePointer<JSExportInfo> = .allocate(capacity: 1)
            info.initialize(to: JSExportInfo(type: nil, jsClassRef: functionRef, instance: nil, callback: value))
            let functionObject = JSObjectMake(context, functionRef, nil)
            JSObjectSetPrivate(functionObject, info)
            JSObjectSetProperty(context, prototype, name.ref, functionObject, JSPropertyAttributes(kJSPropertyAttributeNone), nil)
        }
    }
    
    if let properties {
        for (key, value) in properties {
            let name = JSStringRefWrapper(value: key)
            let v = value.getter()?.jsValue(context: context)
            let attrs = (value.setter == nil ?
                         JSPropertyAttributes(kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete) :
                            JSPropertyAttributes(kJSPropertyAttributeDontDelete))
            JSObjectSetProperty(context, prototype, name.ref, v, attrs, nil)
        }
    }
    
    JSObjectSetPrototype(context, object, prototype)
}

internal func class_constructor(
    _ ctx: JSContextRef?,
    _ object: JSObjectRef?,
    _ argumentCount: Int,
    _ arguments: UnsafePointer<JSValueRef?>?,
    _ exception: UnsafeMutablePointer<JSValueRef?>?
) -> JSObjectRef? {
    guard let context = ctx else { return nil }
    guard let object else { return nil }
    guard let classInfo = JSExportBookkeeping[object] else { return nil }
    
    let newObject = JSObjectMake(ctx, classInfo.classRef, nil)
    
    let info: UnsafeMutablePointer<JSExportInfo> = .allocate(capacity: 1)
    let instance = classInfo.nativeType.init()
    instance.valueRef = newObject
    info.initialize(to: JSExportInfo(type: classInfo.nativeType, jsClassRef: classInfo.classRef, instance: instance, callback: nil))

    JSObjectSetPrivate(newObject, info)
    
    updatePrototype(object: newObject, context: context, properties: instance.exportProperties, methods: instance.exportMethods)
    
    let nativeArgs: [JSConvertible] = (0..<argumentCount).map {
        guard let result = valueRefToType(context: context, value: arguments![$0]) else { return NSNull() }
        return result
    }
    instance.construct(args: nativeArgs)
    
    return newObject
}

internal func class_finalize(_ object: JSObjectRef?) -> Void {
    guard let object else { return }
    JSExportBookkeeping.removeValue(forKey: object)
    guard let priv = JSObjectGetPrivate(object) else { return }
    let info = priv.assumingMemoryBound(to: JSExportInfo.self)
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
    guard let context = ctx else { return nil }
    guard let priv = JSObjectGetPrivate(object) else { return nil }
    let info = priv.assumingMemoryBound(to: JSExportInfo.self)
    let nativeArgs: [JSConvertible] = (0..<argumentCount).map {
        guard let result = valueRefToType(context: context, value: arguments![$0]) else { return NSNull() }
        return result
    }
    let result = info.pointee.callback?(nativeArgs)
    return jsTyped(result, context: context)
}

internal func function_finalize(_ object: JSObjectRef?) -> Void {
    guard let object else { return }
    guard let priv = JSObjectGetPrivate(object) else { return }
    let info = priv.assumingMemoryBound(to: JSExportInfo.self)
    info.deinitialize(count: 1)
    info.deallocate()
}

