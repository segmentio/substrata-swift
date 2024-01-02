//
//  Conversion.swift
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

internal func valueRefToType(context: JSContextRef, value: JSValueRef?) -> JSConvertible? {
    guard let value = value else { return nil }
    if JSValueIsUndefined(context, value) {
        return nil
    }
    if JSValueIsBoolean(context, value) {
        return Bool.from(jsValue: value, context: context)
    }
    if JSValueIsString(context, value) {
        return String.from(jsValue: value, context: context)
    }
    if JSValueIsNull(context, value) {
        return NSNull.from(jsValue: value, context: context)
    }
    if JSValueIsNumber(context, value) {
        // try to get the appropriate type back ...
        // JS has no notion of UInt, only Double/Int.
        if let d = Double.from(jsValue: value, context: context) {
            if d.isInteger {
                return Int(d)
            } else {
                return d
            }
        }
    }
    if JSValueIsArray(context, value) {
        return Array<JSConvertible>.from(jsValue: value, context: context)
    }
    
    let globalObject = JSContextGetGlobalContext(context)
    let errorName = JSStringRefWrapper(value: "Error")
    let errorRef = JSObjectGetProperty(context, globalObject, errorName.ref, nil)
    if let errorRef = errorRef, JSValueIsInstanceOfConstructor(context, value, errorRef, nil) {
        return JSError(value: value, context: context)
    }
    
    if JSObjectIsFunction(context, value) {
        return JSFunction(function: value, context: context)
    }
    
    if JSValueIsObject(context, value) {
        if isNativeAndNotASubclass(value: value, context: context) {
            return JSExport.from(jsValue: value, context: context)
        } else {
            return JSObject(object: value, context: context)
        }
    }
    
    return nil
}

extension Bool: JSConvertible {
    public static func from(jsValue: JSValueRef, context: JSContextRef) -> Self? {
        return JSValueToBoolean(context, jsValue)
    }
    
    public func jsValue(context: JSContextRef) -> JSValueRef? {
        return JSValueMakeBoolean(context, self)
    }
    
    public var string: String {
        switch self {
        case true:
            return "true"
        case false:
            return "false"
        }
    }
}

extension Double: JSConvertible {
    public static func from(jsValue: JSValueRef, context: JSContextRef) -> Self? {
        return JSValueToNumber(context, jsValue, nil)
    }
    
    public func jsValue(context: JSContextRef) -> JSValueRef? {
        return JSValueMakeNumber(context, self)
    }
    
    public var string: String {
        return "\(self)"
    }
}

extension Int: JSConvertible {
    public static func from(jsValue: JSValueRef, context: JSContextRef) -> Self? {
        return Int(JSValueToNumber(context, jsValue, nil))
    }
    
    public func jsValue(context: JSContextRef) -> JSValueRef? {
        return JSValueMakeNumber(context, Double(self))
    }
    
    public var string: String {
        return "\(self)"
    }
}

extension UInt: JSConvertible {
    public static func from(jsValue: JSValueRef, context: JSContextRef) -> Self? {
        return UInt(JSValueToNumber(context, jsValue, nil))
    }
    
    public func jsValue(context: JSContextRef) -> JSValueRef? {
        return JSValueMakeNumber(context, Double(self))
    }
    
    public var string: String {
        return "\(self)"
    }
}

extension Decimal: JSConvertible {
    public static func from(jsValue: JSValueRef, context: JSContextRef) -> Self? {
        return Decimal(floatLiteral: JSValueToNumber(context, jsValue, nil))
    }
    
    public func jsValue(context: JSContextRef) -> JSValueRef? {
        return JSValueMakeNumber(context, self.doubleValue)
    }
    
    public var string: String {
        return "\(self)"
    }
}

extension String: JSConvertible {
    public static func from(jsValue: JSValueRef, context: JSContextRef) -> Self? {
        return String.from(jsString: JSValueToStringCopy(context, jsValue, nil))
    }
    
    public func jsValue(context: JSContextRef) -> JSValueRef? {
        let str = JSStringRefWrapper(value: self)
        return JSValueMakeString(context, str.ref)
    }
    
    public var string: String {
        return "\"\(self)\""
    }
}

extension NSNull: JSConvertible {
    public static func from(jsValue: JSValueRef, context: JSContextRef) -> Self? {
        return NSNull() as? Self
    }
    
    public func jsValue(context: JSContextRef) -> JSValueRef? {
        return JSValueMakeNull(context)
    }
    
    public var string: String {
        return "null"
    }
}

extension Array: JSConvertible where Element == JSConvertible {
    public static func from(jsValue: JSValueRef, context: JSContextRef) -> Self? {
        var result = [JSConvertible]()
        let lengthProperty = JSStringRefWrapper(value: "length")
        let v = JSObjectGetProperty(context, jsValue, lengthProperty.ref, nil)
        if let length: Int = valueRefToType(context: context, value: v)?.typed() {
            for i in 0..<length {
                let itemRef = JSObjectGetPropertyAtIndex(context, jsValue, UInt32(i), nil)
                if let itemValue = valueRefToType(context: context, value: itemRef) {
                    result.append(itemValue)
                }
            }
        }
        return result
    }
    
    public func jsValue(context: JSContextRef) -> JSValueRef? {
        let result = JSObjectMakeArray(context, 0, nil, nil)
        for i in 0..<count {
            let value = self[i]
            JSObjectSetPropertyAtIndex(context, result, UInt32(i), jsTyped(value, context: context), nil)
        }
        return result
    }
    
    public var string: String {
        let stringArray = self.map { $0.string }
        let result = stringArray.joined(separator: ", ")
        return "[\(result)]"
    }
    
    public func atIndex(_ index: Int) -> JSConvertible? {
        if index < count {
            return self[index]
        }
        return nil
    }
}

extension Dictionary: JSConvertible where Key == String, Value == JSConvertible {
    public static func from(jsValue: JSValueRef, context: JSContextRef) -> Dictionary<Key, Value>? {
        var result = [String: JSConvertible]()
        let properties = properties(value: jsValue, context: context)
        for key in properties {
            let propertyName = JSStringRefWrapper(value: key)
            let v = JSObjectGetProperty(context, jsValue, propertyName.ref, nil)
            let value = valueRefToType(context: context, value: v)
            result[key] = value
        }
        return result
    }
    
    public func jsValue(context: JSContextRef) -> JSValueRef? {
        guard let result = JSObjectMake(context, nil, nil) else { return nil }
        for (key, value) in self {
            let jsString = JSStringRefWrapper(value: key)
            let prop = jsString.ref
            JSObjectSetProperty(context, result, prop, jsTyped(value, context: context), 0, nil)
        }
        return result
    }
    
    public var string: String {
        let stringArray = self.map { String(humanized: $0) + ": \($1.string)" }
        let result = stringArray.joined(separator: ", ")
        return "{\(result)}"
    }
    
    internal static func properties(value: JSValueRef, context: JSContextRef) -> [String] {
        let names = JSObjectCopyPropertyNames(context, value)
        defer { JSPropertyNameArrayRelease(names) }
        
        let count = JSPropertyNameArrayGetCount(names)
        let list = (0..<count).map { JSPropertyNameArrayGetNameAtIndex(names, $0)! }
        
        var result = [String]()
        for item in list {
            if let s = String.from(jsString: item) { result.append(s) }
        }
        return result

    }
}

public struct JSError: JSConvertible, CustomStringConvertible, CustomDebugStringConvertible {
    public static func from(jsValue: JSValueRef, context: JSContextRef) -> JSError? {
        return Self.init(value: jsValue, context: context)
    }
    
    public func jsValue(context: JSContextRef) -> JSValueRef? {
        // it's not expected that JS errors are created in native
        // and flow back into JS.
        return nil
    }
    
    public var string: String {
        return """
        Javascript Error:
            Error: (\(name ?? "unknown"), \(message ?? "unknown"))
            Cause: \(cause ?? "unknown")
            Stack: \(stack ?? "unknown")
        """
    }
    
    public init(value: JSValueRef, context: JSContextRef) {
        name = Self.value(for: "name", object: value, context: context)
        message = Self.value(for: "message", object: value, context: context)
        cause = Self.value(for: "cause", object: value, context: context)
        stack = Self.value(for: "stack", object: value, context: context)
    }
    
    internal let name: String?
    internal let message: String?
    internal let cause: String?
    internal let stack: String?
    
    internal static func value(for name: String, object: JSValueRef, context: JSContextRef) -> String? {
        let propertyName = JSStringRefWrapper(value: name)
        let v = JSObjectGetProperty(context, object, propertyName.ref, nil)
        let s: String? = valueRefToType(context: context, value: v)?.typed()
        return s
    }
    
    public var description: String {
        return string
    }
    
    public var debugDescription: String {
        return string
    }
}

extension JSExport: JSConvertible, CustomStringConvertible, CustomDebugStringConvertible {
    public static func from(jsValue: JSValueRef, context: JSContextRef) -> Self? {
        let info = JSObjectGetPrivate(jsValue).assumingMemoryBound(to: JSExportInfo.self)
        return info.pointee.instance as? Self
    }
    
    public func jsValue(context: JSContextRef) -> JSValueRef? {
        return valueRef
    }
    
    public var string: String {
        // will be the name of the class conforming to JSExport
        return "\(Self.self)"
    }
    
    public var description: String {
        return string
    }
    
    public var debugDescription: String {
        return string
    }
}


// MARK: - JSCallable Types

internal protocol JSCallable: JSConvertible {
    var valueRef: JSValueRef { get }
    var context: JSContextRef { get }
    /// implement this as weak
    var engine: JSEngine? { get set }
}
extension JSEngine {
    internal func makeCallableIfNecessary(_ value: inout JSConvertible?) {
        if var v = value as? JSCallable {
            v.engine = self
            value = v
        }
    }
}

public class JSObject: JSConvertible, JSCallable, CustomStringConvertible, CustomDebugStringConvertible {
    internal let valueRef: JSValueRef
    internal let context: JSContextRef
    internal weak var engine: JSEngine? = nil
    
    public static func from(jsValue: JSValueRef, context: JSContextRef) -> Self? {
        return Self.init(object: jsValue, context: context)
    }
    
    public func jsValue(context: JSContextRef) -> JSValueRef? {
        return valueRef
    }
    
    public var string: String {
        return String(describing: dictionary)
    }
    
    public var description: String {
        return string
    }
    
    public var debugDescription: String {
        return string
    }
    
    public var dictionary: [String: JSConvertible]? {
        var result = [String: JSConvertible]()
        let properties = self.keys
        for key in properties {
            let propertyName = JSStringRefWrapper(value: key)
            let v = JSObjectGetProperty(context, valueRef, propertyName.ref, nil)
            let value = valueRefToType(context: context, value: v)
            result[key] = value
        }
        return result
    }
    
    public var keys: [String] {
        let names = JSObjectCopyPropertyNames(context, valueRef)
        defer { JSPropertyNameArrayRelease(names) }
        
        let count = JSPropertyNameArrayGetCount(names)
        let list = (0..<count).map { JSPropertyNameArrayGetNameAtIndex(names, $0)! }
        
        var result = [String]()
        for item in list {
            if let s = String.from(jsString: item) { result.append(s) }
        }
        return result
    }
    
    public var className: String {
        return engine?.evaluate(script: "this.constructor.name", this: valueRef)?.string ?? "Unknown"
    }
    
    internal required init(object: JSValueRef, context: JSContextRef) {
        self.valueRef = object
        self.context = context
    }
    
    subscript(_ property: String) -> JSConvertible? {
        get {
            let value = engine?.run(closure: {
                let propertyName = JSStringRefWrapper(value: property)
                let v = JSObjectGetProperty(context, valueRef, propertyName.ref, nil)
                let value = valueRefToType(context: context, value: v)
                engine?.makeCallableIfNecessary(value)
                return value
            })
            return value
        }
        set {
            engine?.run(closure: {
                let propertyName = JSStringRefWrapper(value: property)
                JSObjectSetProperty(context, valueRef, propertyName.ref, newValue?.jsValue(context: context), 0, nil)
                return nil
            })
        }
    }
    
    public func call(functionName: String, args: [JSConvertible?]) -> JSConvertible? {
        return engine?.call(functionName: functionName, this: valueRef, args: args)
    }
}

public class JSFunction: JSConvertible, JSCallable, CustomStringConvertible, CustomDebugStringConvertible {
    internal let valueRef: JSValueRef
    internal let context: JSContextRef
    internal weak var engine: JSEngine? = nil
    
    public static func from(jsValue: JSValueRef, context: JSContextRef) -> Self? {
        return Self.init(function: jsValue, context: context)
    }
    
    public func jsValue(context: JSContextRef) -> JSValueRef? {
        return valueRef
    }
    
    public var string: String {
        return "<js function>"
    }
    
    internal required init(function: JSValueRef, context: JSContextRef) {
        self.valueRef = function
        self.context = context
    }
    
    public var description: String {
        return string
    }
    
    public var debugDescription: String {
        return string
    }
    
    public func call(args: [JSConvertible?]) -> JSConvertible? {
        return engine?.call(function: self, args: args)
    }
}
