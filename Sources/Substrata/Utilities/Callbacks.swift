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

// MARK: - Classes

internal func genericClassCreate(_ type: JSExport.Type, name: String, staticProps: UnsafePointer<JSStaticValue>?) -> JSClassRef {
    let classRef: JSClassRef = name.withCString { cName in
        var classDef = JSClassDefinition(
            version: 1,
            attributes: JSClassAttributes(kJSClassAttributeNone),
            className: cName,
            parentClass: nil,
            staticValues: staticProps,
            staticFunctions: nil,
            initialize: nil,
            finalize: class_finalize,
            hasProperty: nil,
            getProperty: property_getter,
            setProperty: property_setter,
            deleteProperty: nil,
            getPropertyNames: nil,
            callAsFunction: nil,
            callAsConstructor: class_constructor,
            hasInstance: class_instanceof,
            convertToType: nil
        )
        return JSClassCreate(&classDef)
    }
    return classRef
}

internal func genericFunctionCreate(_ function: JSFunctionDefinition) -> JSClassRef {
    var classDefinition = JSClassDefinition()
    classDefinition.callAsFunction = function_callback
    classDefinition.finalize = function_finalize
    return JSClassCreate(&classDefinition)
}

internal func addMethods(object: JSObjectRef?, context: JSContextRef, methods: [String: JSFunctionDefinition]?)
{
    guard let object else { return }
   
    if let methods {
        print(methods)
        for (key, value) in methods {
            let name = JSStringRefWrapper(value: key)
            let functionRef = genericFunctionCreate(value)
            let info: UnsafeMutablePointer<JSExportInfo> = .allocate(capacity: 1)
            info.initialize(to: JSExportInfo(type: nil, jsClassRef: functionRef, instance: nil, callback: value))
            let functionObject = JSObjectMake(context, functionRef, nil)
            JSObjectSetPrivate(functionObject, info)
            JSObjectSetProperty(context, object, name.ref, functionObject, JSPropertyAttributes(kJSPropertyAttributeNone), nil)
        }
    }
}

internal func addProperties(object: JSObjectRef?, context: JSContextRef, properties: [String: JSProperty]) {
    
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
    guard let classInfo = JSExport.getEntry(ref: object) else { return nil }
    
    let newObject = JSObjectMake(ctx, classInfo.classRef, nil)
    
    let info: UnsafeMutablePointer<JSExportInfo> = .allocate(capacity: 1)
    let instance = classInfo.nativeType.init()
    instance.valueRef = newObject
    info.initialize(to: JSExportInfo(type: classInfo.nativeType, jsClassRef: classInfo.classRef, instance: instance, callback: nil))

    JSObjectSetPrivate(newObject, info)
    
    // add our methods to the prototype, NOT newObject.
    if let proto = JSObjectGetPrototype(context, newObject) {
        addMethods(object: proto, context: context, methods: instance.exportedMethods())
    }
    
    let nativeArgs: [JSConvertible] = (0..<argumentCount).map {
        guard let result = valueRefToType(context: context, value: arguments![$0]) else { return NSNull() }
        return result
    }
    instance.construct(args: nativeArgs)
    
    return newObject
}

internal func class_finalize(_ object: JSObjectRef?) -> Void {
    guard let object else { return }
    JSExport.removeEntry(ref: object)
    guard let priv = JSObjectGetPrivate(object) else { return }
    let info = priv.assumingMemoryBound(to: JSExportInfo.self)
    info.deinitialize(count: 1)
    info.deallocate()
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


// MARK: - Properties

internal func property_getter(
    _ ctx: JSContextRef?,
    _ object: JSObjectRef?,
    _ propertyNameRef: JSStringRef?,
    _ exception: UnsafeMutablePointer<JSValueRef?>?
) -> JSValueRef? {
    var result: JSValueRef? = nil
    
    guard let propertyNameRef = propertyNameRef else { return result }
    guard let propertyName = String.from(jsString: propertyNameRef) else { return result }
    guard let context = ctx else { return result }
    guard let priv = JSObjectGetPrivate(object) else { return result }
    
    let info = priv.assumingMemoryBound(to: JSExportInfo.self)
    
    if let instance = info.pointee.instance {
        if let property = instance.exportedProperties()[propertyName] {
            let v = property.getter()?.jsValue(context: context)
            result = v
        }
    }
    
    return result
}

internal func property_setter(
    _ ctx: JSContextRef?,
    _ object: JSObjectRef?,
    _ propertyNameRef: JSStringRef?,
    _ value: JSValueRef?,
    _ exception: UnsafeMutablePointer<JSValueRef?>?
) -> Bool {
    var result = false
    
    guard let propertyNameRef = propertyNameRef else { return result }
    guard let propertyName = String.from(jsString: propertyNameRef) else { return result }
    guard let context = ctx else { return result }
    guard let priv = JSObjectGetPrivate(object) else { return result }
    
    let info = priv.assumingMemoryBound(to: JSExportInfo.self)
    
    if let instance = info.pointee.instance {
        if let property = instance.exportedProperties()[propertyName], let setter = property.setter {
            let v = valueRefToType(context: context, value: value)
            setter(v)
            result = true
        }
    }
    
    return result
}

// MARK: - Functions

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

