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

extension JSObject {
    public func addProperty(name: String, getter: @escaping JSPropertyGetCallback, setter: JSPropertySetCallback?) {
        guard var privateData = privateData else { return }
        let prop = JSProperty(//context: context,
                              name: name,
                              getter: getter,
                              setter: setter)
        privateData.addedProperties[name] = prop
        self.privateData = privateData
    }
    
    public func addMethod(name: String, method function: @escaping JSFunctionCallback) {
        guard var privateData = privateData else { return }
        let method = JSMethod(//context: context,
                              name: name,
                              method: function)
        privateData.addedMethods[name] = method
        self.privateData = privateData
        self[name] = JSFunction(context: context, callback: function)
    }
}

// MARK: - Trampoline definitions

internal struct JSProperty {
    let name: String
    let getter: JSPropertyGetCallback?
    let setter: JSPropertySetCallback?
}

internal struct JSMethod {
    let name: String
    let method: JSFunctionCallback
}

internal struct JSExportInfo {
    weak var context: JSContext?
    let type: JSExport.Type
    var instance: AnyObject? = nil
    var addedProperties = [String: JSProperty]()
    var addedMethods = [String: JSMethod]()
}

// MARK: - C-style callbacks

internal func class_finalize(_ object: JSObjectRef?) -> Void {
    let info = JSObjectGetPrivate(object).assumingMemoryBound(to: JSExportInfo.self)
    info.deinitialize(count: 1)
    info.deallocate()
}

internal func class_constructor(
    _ ctx: JSContextRef?,
    _ object: JSObjectRef?,
    _ argumentCount: Int,
    _ arguments: UnsafePointer<JSValueRef?>?,
    _ exception: UnsafeMutablePointer<JSValueRef?>?
) -> JSObjectRef? {
    let info = JSObjectGetPrivate(object).assumingMemoryBound(to: JSExportInfo.self)
    guard let context = info.pointee.context else { return nil }
    
    do {
        let params = (0..<argumentCount).map { JSPrimitive.construct(from: arguments![$0]!, context: context) }
        let instance = try info.pointee.type.init(context: context, params: params)
        let result = try JSObject(context: context, instance: instance)

        // add the prototype from our class definition
        let prototype = JSObjectGetPrototype(context.ref, object)
        JSObjectSetPrototype(context.ref, result.ref, prototype)

        return result.ref
    } catch {
        let error = JSError(context: context, message: "\(error)")
        exception?.pointee = error.ref
        return nil
    }
}

internal func class_instanceof(
    _ ctx: JSContextRef?,
    _ constructor: JSObjectRef?,
    _ possibleInstance: JSValueRef?,
    _ exception: UnsafeMutablePointer<JSValueRef?>?
) -> Bool {
    let info = JSObjectGetPrivate(constructor).assumingMemoryBound(to: JSExportInfo.self)
    guard let context = info.pointee.context else { return false }
    let prototype_0 = JSObjectGetPrototype(context.ref, constructor)
    let prototype_1 = JSObjectGetPrototype(context.ref, possibleInstance)
    return JSValueIsStrictEqual(context.ref, prototype_0, prototype_1)
}
