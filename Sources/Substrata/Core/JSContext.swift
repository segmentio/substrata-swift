//
//  File.swift
//  
//
//  Created by Brandon Sneed on 5/25/22.
//

import Foundation

#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

public class JSContext {
    internal let vm: JSContextGroupRef
    internal let ref: JSGlobalContextRef
    internal var globalRef: JSContextRef
    internal var registeredClasses = [String: JSClassRef]()
    internal var errorRef: JSValueRef? = nil
    internal var exception: JSValueRef? {
        didSet {
            guard let e = exception else { return }
            if let callback = exceptionHandler {
                callback(self, JSPrimitive.construct(from: e, context: self))
            }
        }
    }
    
    public var exceptionHandler: ((JSContext, JSPrimitive) -> Void)?
    
    public init() {
        self.vm = JSContextGroupCreate()
        self.ref = JSGlobalContextCreateInGroup(vm, nil)
        self.globalRef = JSContextGetGlobalObject(self.ref)
        self.errorRef = self["Error"].ref
        
        #if DEBUG
        if isUnitTesting {
            JSLeaks.objects.append(self)
        }
        #endif
    }
    
    deinit {
        for classRef in registeredClasses.values {
            JSClassRelease(classRef)
        }
        JSContextGroupRelease(vm)
        JSGlobalContextRelease(ref)
    }
    
    @discardableResult
    public func evaluate(script: String, this: JSPrimitive? = nil, sourceURL: URL? = nil) -> JSPrimitive {
        guard let jsScript = script.jsString else { return undefined }
        let jsSource = sourceURL?.absoluteString.jsString
        
        var result: JSPrimitive
        if let evalRef = JSEvaluateScript(ref, jsScript.ref, this?.ref, jsSource?.ref, 0, &exception) {
            result = JSPrimitive.construct(from: evalRef, context: self)
        } else {
            result = undefined
        }
        return result
    }
}

extension JSContext {
    public subscript(property: String) -> JSPrimitive {
        get {
            var result = global[property]
            if result.isUndefined {
                // if we can't find it in the global context,
                // they're probably looking for a variable in the
                // current eval context.
                result = evaluate(script: property)
            }
            return result
        }
        set {
            global[property] = newValue
        }
    }
    
    public var global: JSObject {
        return JSObject(context: self, ref: globalRef)
    }
    
    public func hasProperty(_ property: String) -> Bool {
        return global.hasProperty(property)
    }
    
    @discardableResult
    public func removeProperty(_ property: String) -> Bool {
        return global.removeProperty(property)
    }
}
