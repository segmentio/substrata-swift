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

public protocol JSConvertible {
    func jsValue(context: JSContext) -> JSPrimitive
}

public class JSPrimitive {
    internal unowned let context: JSContext
    internal var ref: JSValueRef
    internal var betterDescription: String? = nil

    required public init(context: JSContext, ref: JSValueRef) {
        self.context = context
        self.ref = ref
        JSValueProtect(context.ref, ref)
        #if DEBUG
        if isUnitTesting {
            JSLeaks.objects.append(self)
        }
        #endif
    }
    
    deinit {
        JSValueUnprotect(context.ref, ref)
    }
    
    public var value: JSConvertible? {
        return nil
    }
    
    public func value<T: JSConvertible>(_ type: T.Type) -> T? {
        /*// if they want it back as a primitive, give it to them.
        if T.self is JSPrimitive.Type {
            return self as? T
        }*/
        // try a little harder for numbers ...
        // they could be asking for an Int where
        // we only deal with Double internally.
        guard let v = value else { return nil }
        if let d = v as? Double {
            switch type {
            case is Double.Type:
                return d as? T
            case is Int.Type:
                return Int(d) as? T
            case is UInt.Type:
                return UInt(d) as? T
            case is Float.Type:
                return Float(d) as? T
            default:
                return nil
            }
        }
        
        return v as? T
    }
    
    public func jsDescription() -> String? { return nil }
}

extension JSPrimitive: JSConvertible {
    public func jsValue(context: JSContext) -> JSPrimitive {
        return self
    }
}

extension JSPrimitive: CustomStringConvertible {
    public var description: String {
        if let jsDesc = jsDescription() {
            return jsDesc
        }
        if let jsStr = String.from(jsString: JSValueToStringCopy(context.ref, ref, &context.exception)) {
            return jsStr
        }
        return "unknown"
    }
}

extension JSPrimitive {
    static public func construct(from ref: JSValueRef?, context: JSContext) -> JSPrimitive {
        guard let ref = ref else { return context.undefined }
        if JSValueIsUndefined(context.ref, ref) {
            return context.undefined
        }
        if JSValueIsNull(context.ref, ref) {
            let null = JSNull(context: context)
            return null
        }
        if JSValueIsBoolean(context.ref, ref) {
            let bool = JSBoolean(context: context, ref: ref)
            return bool
        }
        if JSValueIsNumber(context.ref, ref) {
            let number = JSNumber(context: context, ref: ref)
            return number
        }
        if JSValueIsString(context.ref, ref) {
            let string = JSString(context: context, ref: ref)
            return string
        }
        if JSValueIsArray(context.ref, ref) {
            let array = JSArray(context: context, ref: ref)
            return array
        }

        if let errorRef = context.errorRef, JSValueIsInstanceOfConstructor(context.ref, ref, errorRef, nil) {
            let error = JSError(context: context, ref: ref)
            return error
        }

        if JSObjectIsFunction(context.ref, ref) {
            let function = JSFunction(context: context, ref: ref)
            return function
        }
        if JSValueIsObject(context.ref, ref) {
            let object = JSObject(context: context, ref: ref)
            return object
        }
        return JSPrimitive(context: context, ref: ref)
    }
    
    static public func construct(from value: JSConvertible?, context: JSContext) -> JSPrimitive {
        guard let value = value else { return context.undefined }
        return value.jsValue(context: context)
    }
}

extension JSPrimitive {
    public func typed<T: JSPrimitive>(_ type: T.Type) -> T? {
        return self as? T
    }
}

extension JSPrimitive {
    public var isArray: Bool {
        if self is JSArray { return true }
        return JSValueIsArray(context.ref, ref)
    }

    public var isObject: Bool {
        if self is JSObject { return true }
        return JSValueIsObject(context.ref, ref)
    }
    
    public var isFunction: Bool {
        if self is JSFunction { return true }
        return JSObjectIsFunction(context.ref, ref)
    }
    
    public var isBoolean: Bool {
        if self is JSBoolean { return true }
        return JSValueIsBoolean(context.ref, ref)
    }

    public var isNumber: Bool {
        if self is JSNumber { return true }
        return JSValueIsNumber(context.ref, ref)
    }

    public var isString: Bool {
        if self is JSString { return true }
        return JSValueIsString(context.ref, ref)
    }

    public var isUndefined: Bool {
        if self is JSUndefined { return true }
        return JSValueIsUndefined(context.ref, ref)
    }
    
    public var isNull: Bool {
        if self is JSNull { return true }
        return JSValueIsNull(context.ref, ref)
    }
    
    public var isError: Bool {
        let error = context["Error"]
        return JSValueIsInstanceOfConstructor(context.ref, ref, error.ref, nil)
    }
}

