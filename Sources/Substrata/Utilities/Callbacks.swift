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

internal func genericClassCreate(_ type: JSExport.Type, name: String) -> JSClassRef {
    var classDefinition = JSClassDefinition()
    let classRef: JSClassRef = name.withCString { cName in
        classDefinition.className = cName
        classDefinition.attributes = JSClassAttributes(kJSClassAttributeNone)
        classDefinition.callAsConstructor = class_constructor
        classDefinition.finalize = class_finalize
        classDefinition.hasInstance = class_instanceof
        classDefinition.getProperty = property_getter
        classDefinition.setProperty = property_setter
        classDefinition.hasProperty = property_checker
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
            print("Adding method \(key)")
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
            print("Adding property \(key)")
            let name = JSStringRefWrapper(value: key)
            let v = value.getter()?.jsValue(context: context)
            let attrs = (value.setter == nil ?
                         JSPropertyAttributes(kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete) :
                            JSPropertyAttributes(kJSPropertyAttributeDontDelete))
            JSObjectSetProperty(context, prototype, name.ref, v, attrs, nil)
        }
    }
    
    let prototypeName = JSStringRefWrapper(value: "prototype")
    JSObjectSetPrototype(context, object, prototype)
    JSObjectSetProperty(context, object, prototypeName.ref, prototype, JSPropertyAttributes(kJSPropertyAttributeNone), nil)
}

internal func class_instanceof(
    _ ctx: JSContextRef?,
    _ constructor: JSObjectRef?,
    _ possibleInstance: JSValueRef?,
    _ exception: UnsafeMutablePointer<JSValueRef?>?
) -> Bool {
    guard let context = ctx else { return false }
    let prototype_0 = JSObjectGetPrototype(context, constructor)
    let prototype_1 = JSObjectGetPrototype(context, possibleInstance)
    return JSValueIsStrictEqual(context, prototype_0, prototype_1)
}

internal func class_constructor(
    _ ctx: JSContextRef?,
    _ object: JSObjectRef?,
    _ argumentCount: Int,
    _ arguments: UnsafePointer<JSValueRef?>?,
    _ exception: UnsafeMutablePointer<JSValueRef?>?
) -> JSObjectRef? {
    guard let context = ctx else { return nil }
    
    let info = JSObjectGetPrivate(object).assumingMemoryBound(to: JSExportInfo.self)
    let classRef = info.pointee.jsClassRef
    let newObject = JSObjectMake(ctx, classRef, nil)

    let instanceInfo: UnsafeMutablePointer<JSExportInfo> = .allocate(capacity: 1)
    guard let instance = info.pointee.type?.init() else { return nil }
    instanceInfo.initialize(to: JSExportInfo(type: info.pointee.type, jsClassRef: classRef, instance: instance, callback: nil))
    JSObjectSetPrivate(newObject, instanceInfo)
    instance.valueRef = newObject
    
    print("updating prototype for instance of \(String(describing: info.pointee.type))")
    updatePrototype(object: newObject, context: context, properties: instance.exportProperties, methods: instance.exportMethods)
    
    let nativeArgs = (0..<argumentCount).map { valueRefToType(context: context, value: arguments![$0]!) }
    instance.construct(args: nativeArgs)
    
    return newObject
}

internal func class_finalize(_ object: JSObjectRef?) -> Void {
    let info = JSObjectGetPrivate(object).assumingMemoryBound(to: JSExportInfo.self)
    info.deinitialize(count: 1)
    info.deallocate()
}

internal func property_getter(
    _ ctx: JSContextRef?,
    _ object: JSObjectRef?,
    _ propertyName: JSStringRef?,
    _ exception: UnsafeMutablePointer<JSValueRef?>?
) -> JSValueRef? {
    guard let context = ctx else { return nil }
    guard let propertyName = propertyName else { return nil }
    
    var result: JSValueRef? = nil

    let info = JSObjectGetPrivate(object).assumingMemoryBound(to: JSExportInfo.self)
    
    // check if it's an instance
    let props = info.pointee.instance?.exportProperties
    /*if props == nil {
        // it's not, so fall back to the static props.
        props = info.pointee.type?.exportProperties
    }*/
    
    if let props = props {
        guard let propName = String.from(jsString: propertyName) else { return nil }
        if let property = props[propName] {
            let value = property.getter()
            result = jsTyped(value, context: context)
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
    guard let context = ctx else { return false }
    guard let propertyName = propertyName else { return false }
    
    var result: Bool = false

    let info = JSObjectGetPrivate(object).assumingMemoryBound(to: JSExportInfo.self)
    
    // check if it's an instance
    let props = info.pointee.instance?.exportProperties
    /*if props == nil {
        // it's not, so fall back to the static props.
        props = info.pointee.type?.exportProperties
    }*/
    
    guard let propName = String.from(jsString: propertyName) else { return false }
    if let props = props, let property = props[propName], let setter = property.setter {
        let value = valueRefToType(context: context, value: value)
        setter(value)
        result = true
    }
    return result
}

internal func property_checker(
    _ ctx: JSContextRef?,
    _ object: JSObjectRef?,
    _ propertyName: JSStringRef?
) -> Bool {
    guard let propertyName = propertyName else { return false }
    
    var result: Bool = false

    let info = JSObjectGetPrivate(object).assumingMemoryBound(to: JSExportInfo.self)
    
    // check if it's an instance
    var props = info.pointee.instance?.exportProperties
    if props == nil {
        // it's not, so fall back to the static props.
        props = info.pointee.type?.exportProperties
    }
    
    // check if it's an instance
    var methods = info.pointee.instance?.exportMethods
    if methods == nil {
        // it's not, so fall back to the static props.
        methods = info.pointee.type?.exportMethods
    }
    
    guard let propName = String.from(jsString: propertyName) else { return false }
    if let props, props[propName] != nil {
        result = true
    }
    /*if let methods, methods[propName] != nil {
        result = true
    }*/
    print("Checking for property \(propName), found? = \(result)")
    return result
}


internal func function_finalize(_ object: JSObjectRef?) -> Void {
    let info = JSObjectGetPrivate(object).assumingMemoryBound(to: JSExportInfo.self)
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
    let info = JSObjectGetPrivate(object).assumingMemoryBound(to: JSExportInfo.self)
    let nativeArgs = (0..<argumentCount).map { valueRefToType(context: context, value: arguments![$0]!) }
    let result = info.pointee.callback?(nativeArgs)
    return jsTyped(result, context: context)
}
