//
//  File.swift
//  
//
//  Created by Brandon Sneed on 1/14/24.
//

import Foundation
import SubstrataQuickJS

internal func typedCall(context: JSContextRef?, magic: Int32, argc: Int32, argv: UnsafeMutablePointer<JSValue>?) -> JSValue {
    var result = JSValue.undefined
    guard let context = context?.opaqueContext else { return result }
    let args = jsArgsToTypes(context: context, argc: argc, argv: argv)
        
    guard let fn: JSFunctionDefinition = context.findExport(functionID: magic) else { return result }
    result = returnJSValueRef(context: context, function: fn, args: args)
    
    return result
}

internal func typedConstruct(context: JSContextRef?, this: JSValue, magic: Int32, argc: Int32, argv: UnsafeMutablePointer<JSValue>?) -> JSValue {
    var result = JSValue.undefined

    guard let context = context?.opaqueContext else { return result }
    
    let args = jsArgsToTypes(context: context, argc: argc, argv: argv)
        
    guard let classType: JSClassInfo = context.findExport(classID: magic) else { return result }
    
    result = js_create_from_ctor(context.ref, this, Int32(classType.classID))
    
    let instance = classType.waitingToAttach ?? classType.type.init()
    let classInstance = JSClassInstanceInfo(type: classType.type, classID: classType.classID, instance: instance)
    let ptr = UnsafeMutablePointer<JSClassInstanceInfo>.allocate(capacity: 1)
    ptr.pointee = classInstance
    JS_SetOpaque(result, ptr)
    
    let instanceAtom = JS_NewAtom(context.ref, "__instanceAtom")
    let classIDValue = JS_NewInt32(context.ref, Int32(classType.classID))
    JS_SetProperty(context.ref, result, instanceAtom, classIDValue)
    // atom's need to be free'd.  they're not reference counted like jsvalue's.
    JS_FreeAtom(context.ref, instanceAtom)
    
    if classType.waitingToAttach == nil {
        instance.construct(args: args)
    }
    
    context.addExport(instance: classInstance)
    
    return result
}

func typedInstanceMethod(context: JSContextRef?, this: JSValue, argc: Int32, argv: UnsafeMutablePointer<JSValue>?, magic: Int32) -> JSValue {
    guard let context = context?.opaqueContext else { return JSValue.undefined }
    guard let methodName = context.findExport(methodID: magic) else { return JSValue.undefined }
            
    print("instance_method2 calling `\(methodName)`.")
    
    // get the classID for `this`.
    let instanceAtom = JS_NewAtom(context.ref, "__instanceAtom")
    let classIDValue = JS_GetProperty(context.ref, this, instanceAtom)
    var classID: Int32 = 0
    JS_ToInt32(context.ref, &classID, classIDValue)
    JS_FreeAtom(context.ref, instanceAtom)
    
    // get the instance information
    let ptr = JS_GetOpaque(this, JSClassID(classID))
    guard let info = ptr?.assumingMemoryBound(to: JSClassInstanceInfo.self) else { return JSValue.undefined }
    guard let instance = info.pointee.instance else { return JSValue.undefined }
    guard let method = instance.exportedMethods[methodName] else { return JSValue.undefined }
    
    let args = jsArgsToTypes(context: context, argc: argc, argv: argv)
    let result = returnJSValueRef(context: context, function: method, args: args)
    
    return result
}

