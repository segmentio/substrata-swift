//
//  File.swift
//  
//
//  Created by Brandon Sneed on 1/14/24.
//

import Foundation
import SubstrataQuickJS

// MARK: - Call conversion funcs

internal func returnJSValueRef(context: JSContext, function: JSFunctionDefinition, args: [JSConvertible]) -> JSValue {
    do {
        let v = try function(args) as? JSInternalConvertible
        if let v = v?.toJSValue(context: context) {
            return v
        }
        return JSValue.undefined
    } catch {
        return context.throwError(error)
    }
}

internal func returnJSValueRef(context: JSContext, function: JSPropertyGetterDefinition) -> JSValue {
    // make sure we're consistent with our types.
    // nil = undefined in js.
    // nsnull = null in js.
    do {
        let v = try function() as? JSInternalConvertible
        if let v = v?.toJSValue(context: context) {
            return v
        }
        return JSValue.undefined
    } catch {
        return context.throwError(error)
    }
}

internal func returnJSValueRef(context: JSContext, function: JSPropertySetterDefinition, arg: JSConvertible?) -> JSValue {
    // make sure we're consistent with our types.
    // nil = undefined in js.
    // nsnull = null in js.
    do {
        try function(arg)
        return JSValue.undefined
    } catch {
        return context.throwError(error)
    }
}

internal func jsArgsToTypes(context: JSContext?, argc: Int32, argv: UnsafeMutablePointer<JSValue>?) -> [JSConvertible] {
    var result = [JSConvertible]()
    guard let argv = argv, argc > 0, argc <= Int32.max else { return result }
    
    for i in 0..<Int(argc) {
        guard i < Int(argc) else { break }  // Extra safety check
        if let v = argv[i].toJSConvertible(context: context) {
            result.append(v)
        } else {
            result.append(NSNull())
        }
    }
    return result
}

// MARK: - Swift type conversions

extension String: JSConvertible, JSInternalConvertible {
    internal static func fromJSValue(_ value: JSValue, context: JSContext) -> String? {
        if JS_IsString(value) > 0 {
            var result: String? = nil
            
            if let str = JS_ToCString(context.ref, value) {
                result = String(cString: str, encoding: .utf8)
                JS_FreeCString(context.ref, str)
            }
            return result
        }
        return nil
    }
    
    internal func toJSValue(context: JSContext) -> JSValue? {
        return JS_NewString(context.ref, self)
    }
    
    public var string: String {
        return "\(self)"
    }
}

extension Swift.Bool: JSConvertible, JSInternalConvertible {
    internal static func fromJSValue(_ value: JSValue, context: JSContext) -> Bool? {
        if JS_IsBool(value) > 0 {
            let b = JS_ToBool(context.ref, value) == 1
            return b
        }
        return nil
    }
    
    internal func toJSValue(context: JSContext) -> JSValue? {
        let b: Int32 = (self == true ? 1 : 0)
        return JS_NewBool(context.ref, b)
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

extension NSNull: JSConvertible, JSInternalConvertible {
    internal static func fromJSValue(_ value: JSValue, context: JSContext) -> Self? {
        if JS_IsNull(value) > 0 {
            return Self.init()
        }
        return nil
    }
    
    internal func toJSValue(context: JSContext) -> JSValue? {
        return JSValue.null
    }
    
    public var string: String {
        return "null"
    }
}

extension NSNumber: JSConvertible, JSInternalConvertible {
    static func fromJSValue(_ value: JSValue, context: JSContext) -> Self? {
        // we're not gonna get a NSNumber back from JS.
        return nil
    }
    
    func toJSValue(context: JSContext) -> JSValue? {
        if isBool() {
            return self.boolValue.toJSValue(context: context)
        } else if isDouble() {
            return self.doubleValue.toJSValue(context: context)
        } else {
            return self.intValue.toJSValue(context: context)
        }
    }
    
    var string: String {
        if isBool() {
            return self.boolValue.string
        } else if isDouble() {
            return self.doubleValue.string
        } else {
            return self.intValue.string
        }
    }
}

extension Double: JSConvertible, JSInternalConvertible {
    internal static func fromJSValue(_ value: JSValue, context: JSContext) -> Double? {
        if JS_IsNumber(value) > 0 {
            var d: Double = 0
            JS_ToFloat64(context.ref, &d, value)
            return d
        }
        return nil
    }
    
    internal func toJSValue(context: JSContext) -> JSValue? {
        let v = JS_NewFloat64(context.ref, self)
        return v
    }
    
    public var string: String {
        return "\(self)"
    }
}

extension Float: JSConvertible, JSInternalConvertible {
    internal static func fromJSValue(_ value: JSValue, context: JSContext) -> Float? {
        if JS_IsNumber(value) > 0 {
            var d: Double = 0
            JS_ToFloat64(context.ref, &d, value)
            return Float(d)
        }
        return nil
    }
    
    internal func toJSValue(context: JSContext) -> JSValue? {
        let v = JS_NewFloat64(context.ref, Double(self))
        return v
    }
    
    public var string: String {
        return "\(self)"
    }
}

extension Int: JSConvertible, JSInternalConvertible {
    internal static func fromJSValue(_ value: JSValue, context: JSContext) -> Int? {
        if JS_IsNumber(value) > 0 {
            var i: Int64 = 0
            JS_ToInt64(context.ref, &i, value)
            return Int(i)
        }
        return nil
    }
    
    internal func toJSValue(context: JSContext) -> JSValue? {
        let v = JS_NewInt64(context.ref, Int64(self))
        return v
    }
    
    public var string: String {
        return "\(self)"
    }
}

extension UInt: JSConvertible, JSInternalConvertible {
    internal static func fromJSValue(_ value: JSValue, context: JSContext) -> UInt? {
        if JS_IsNumber(value) > 0 {
            var i: UInt32 = 0
            JS_ToUint32(context.ref, &i, value)
            return UInt(i)
        }
        return nil
    }
    
    internal func toJSValue(context: JSContext) -> JSValue? {
        let v = JS_NewUint32(context.ref, UInt32(self))
        return v
    }
    
    public var string: String {
        return "\(self)"
    }
}

extension Decimal: JSConvertible, JSInternalConvertible {
    internal static func fromJSValue(_ value: JSValue, context: JSContext) -> Decimal? {
        if JS_IsNumber(value) > 0 {
            var d: Double = 0
            JS_ToFloat64(context.ref, &d, value)
            return Decimal(floatLiteral: d)
        }
        return nil
    }
    
    internal func toJSValue(context: JSContext) -> JSValue? {
        let v = JS_NewFloat64(context.ref, Float64(self.doubleValue))
        return v
    }
    
    public var string: String {
        return "\(self)"
    }
}

extension Dictionary: JSConvertible, JSInternalConvertible where Key == String, Value == JSConvertible {
    static func fromJSValue(_ value: JSValue, context: JSContext) -> Dictionary<Key, Value>? {
        if JS_IsObject(value) > 0 {
            var result = [Key: Value]()
            
            var names: UnsafeMutablePointer<JSPropertyEnum>!
            var count: UInt32 = 0
            JS_GetOwnPropertyNames(context.ref, &names, &count, value, JS_GPN_ENUM_ONLY | JS_GPN_STRING_MASK)
            guard names != nil else { return nil }
            
            var iterator = names!
            for _ in 0..<count {
                if let keyPtr = JS_AtomToCString(context.ref, iterator.pointee.atom) {
                    defer { JS_FreeCString(context.ref, keyPtr) }
                    
                    if let key = String(cString: keyPtr, encoding: .utf8) {
                        let v = JS_GetPropertyStr(context.ref, value, key)
                        defer { v.free(context) }
                        
                        let value = v.toJSConvertible(context: context)
                        result[key] = value
                    }
                }
                
                iterator = iterator.advanced(by: 1)
            }
            
            js_free_prop_enum(context.ref, names, count)
            
            return result
        }
        return nil
    }
    
    func toJSValue(context: JSContext) -> JSValue? {
        let obj = JS_NewObject(context.ref)
        for (key, value) in self {
            guard let v = value as? JSInternalConvertible else { continue }
            guard let v = v.toJSValue(context: context) else { continue }
            JS_SetPropertyStr(context.ref, obj, key, v)
        }
        return obj
    }
    
    public var string: String {
        let stringArray = self.map { String(humanized: $0) + ": \(String(humanized: ($1 as? JSInternalConvertible)?.string))" }
        let result = stringArray.joined(separator: ", ")
        return "{\(result)}"
    }
}

extension Array: JSConvertible, JSInternalConvertible where Element == JSConvertible {
    internal static func fromJSValue(_ value: JSValue, context: JSContext) -> Array<Element>? {
        if JS_IsArray(context.ref, value) > 0 {
            let sizeV = JS_GetPropertyStr(context.ref, value, "length")
            guard let size = sizeV.toJSConvertible(context: context)?.typed(as: Int.self) else { return nil }
            defer { sizeV.free(context) }

            var result = [JSConvertible]()
            for i in 0..<size {
                let v = JS_GetPropertyUint32(context.ref, value, UInt32(i))
                defer { v.free(context) }
                
                let value = v.toJSConvertible(context: context) ?? NSNull()
                result.append(value)
            }
            return result
        }
        return nil
    }

    internal func toJSValue(context: JSContext) -> JSValue? {
        let array = JS_NewArray(context.ref)
        for i in 0..<self.count {
            let v = (self[i] as? JSInternalConvertible)?.toJSValue(context: context) ?? JSValue.undefined
            JS_SetPropertyUint32(context.ref, array, UInt32(i), v)
        }
        return array
    }
    
    public var string: String {
        let stringArray = self.map { String(humanized: ($0 as? JSInternalConvertible)?.string) }
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


// MARK: - Javascript specific type conversions

public class JSClass: JSConvertible, JSInternalConvertible {
    internal let value: JSValue
    internal weak var context: JSContext?
    internal var methods: [String: JSFunction]? = nil
    internal let className: String
    
    internal static func fromJSValue(_ value: JSValue, context: JSContext) -> Self? {
        if JS_IsObject(value) > 0 {
            return Self.init(value: value, context: context)
        }
        return nil
    }
    
    internal func toJSValue(context: JSContext) -> JSValue? {
        // we can't pass things between contexts, so make sure
        // they match.
        if context === self.context {
            return JS_DupValue(context.ref, value)
        }
        return nil
    }
    
    public var string: String {
        if let methods {
            var protoList = methods.keys.map { name in
                return "    \(name): ƒ \(name)()"
            }
            protoList.insert("constructor: ƒ \(className)()", at: 0)
            let proto = protoList.joined(separator: ",\n")
            return """
            \(className) {
              __proto__: {
                \(proto)
              }
            }
            """
        } else {
            return """
            \(className) {
              __proto__: {
                constructor: ƒ \(className)(),
                ...
              }
            }
            """
        }
    }
    
    required internal init?(value: JSValue, context: JSContext) {
        if context.isShuttingDown {
            fatalError()
        }
        if JS_IsObject(value) > 0 {
            let v = JS_DupValue(context.ref, value)
            self.className = value.getClassName(context)
            if self.className != "Object" {
                self.value = v
                self.context = context
            } else {
                v.free(context)
                return nil
            }
        } else {
            return nil
        }
    }
    
    deinit {
        value.free(context)
    }
    
    public subscript(key: String) -> JSConvertible? {
        get {
            return value(for: key)
        }
        
        set(value) {
            setValue(value, for: key)
        }
    }
    
    public func value(for key: String) -> JSConvertible? {
        guard let context else { return nil }
        var result: JSConvertible? = nil
        context.performThreadSafe {
            let r = JS_GetPropertyStr(context.ref, value, key)
            result = r.toJSConvertible(context: context)
        }
        return result
    }
    
    public func setValue(_ value: JSConvertible?, for key: String) {
        guard let context else { return }
        let newValue = value as? JSInternalConvertible
        context.performThreadSafe {
            let jsv = newValue?.toJSValue(context: context) ?? JSValue.null
            JS_SetPropertyStr(context.ref, self.value, key, jsv)
        }
    }
    
    @discardableResult
    public func call(method: String, args: [JSConvertible]?) -> JSConvertible? {
        populateMethodsIfNecessary()
        // call the method if we have it
        guard let methods else { return nil }
        if let function = methods[method] {
            // call is already thread-safe
            return function.call(this: value, args: args)
        }
        return nil
    }
    
    internal static func getClassName(_ value: JSValue, _ context: JSContext?) -> String {
        guard let context else { return "<no context>" }
        if value.hasProperty(context: context, string: "constructor") {
            let const = JS_GetPropertyStr(context.ref, value, "constructor")
            defer { const.free(context) }
            if let obj = JSFunction(value: const, context: context) {
                return obj.name
            }
        }
        return "Object"
    }
    
    internal func populateMethodsIfNecessary() {
        guard let context else { return }
        // go find our methods if we don't have them ...
        let workingValue = value
        if self.methods == nil {
            context.performThreadSafe {
                if let r = context.builtIns?._getInstanceMethodNames?.callRaw(args: [workingValue]) {
                    self.methods = r.toJSConvertible(context: context) as? [String: JSFunction]
                    r.free(context)
                }
            }
        }
    }
}

public class JSFunction: JSConvertible, JSInternalConvertible {
    internal let value: JSValue
    internal weak var context: JSContext?
    internal let name: String
    
    internal static func fromJSValue(_ value: JSValue, context: JSContext) -> Self? {
        if JS_IsFunction(context.ref, value) > 0 {
            return Self.init(value: value, context: context)
        }
        return nil
    }
    
    internal func toJSValue(context: JSContext) -> JSValue? {
        // we can't pass things between contexts, so make sure
        // they match.
        if context === self.context {
            return JS_DupValue(context.ref, value)
        }
        return nil
    }
    
    public var string: String {
        return "ƒ \(name)()"
    }
    
    required internal init?(value: JSValue, context: JSContext) {
        if context.isShuttingDown {
            fatalError()
        }
        if JS_IsFunction(context.ref, value) > 0 {
            self.value = JS_DupValue(context.ref, value)
            self.context = context
            self.name = value.getFunctionName(context)
            return
        }
        return nil
    }
    
    deinit {
        value.free(context)
    }
    
    internal func callRaw(args: [JSValue]?) -> JSValue? {
        guard let context else { return nil }
        let jsResult: JSValue
        
        // short-circuit ...
        if args == nil {
            jsResult = JS_Call(context.ref, value, context.globalRef, 0, nil)
            return jsResult
        }
        
        guard let args else { return nil }
        
        // prepare args
        let jsValuesArray: [JSValue] = args.map { value in
            return value
        }
        
        // call it and see what's up.
        let jsArgs = UnsafeMutablePointer<JSValue>.allocate(capacity: args.count + 1)
        jsArgs.initialize(from: jsValuesArray, count: jsValuesArray.count)
        jsResult = JS_Call(context.ref, value, context.globalRef, Int32(args.count), jsArgs)
        jsArgs.deallocate()
        
        // new fone, who dis?
        return jsResult
    }
    
    @discardableResult
    public func call(this: JSValue? = nil, args: [JSConvertible]?) -> JSConvertible? {
        guard let context else { return nil }
        var result: JSConvertible? = nil
        
        let usingThis = this ?? context.globalRef
        
        context.performThreadSafe {
            // short-circuit ...
            if args == nil {
                let r = JS_Call(context.ref, value, usingThis, 0, nil)
                result = r.toJSConvertible(context: context)
                r.free(context)
                return
            }
            
            guard let args = args as? [JSInternalConvertible] else { return }
            
            // prepare args
            var valuesArray = [JSValue]()
            for i in 0..<args.count {
                let v = args[i].toJSValue(context: context) ?? NSNull().toJSValue(context: context)!
                valuesArray.append(v)
            }
            
            // call it and see what's up.
            let jsArgs = UnsafeMutablePointer<JSValue>.allocate(capacity: args.count + 1)
            jsArgs.initialize(from: valuesArray, count: valuesArray.count)
            let jsResult = JS_Call(context.ref, value, usingThis, Int32(args.count), jsArgs)
            defer { jsResult.free(context) }
            jsArgs.deallocate()
            
            // new fone, who dis?
            result = jsResult.toJSConvertible(context: context)
            
            // cleanup our args
            for v in valuesArray {
                v.free(context)
            }
        }
        return result
    }
}

public final class JSError: JSConvertible, JSInternalConvertible {
    internal static func fromJSValue(_ value: JSValue, context: JSContext) -> JSError? {
        if JS_IsError(context.ref, value) > 0 {
            return JSError(value: value, context: context)
        }
        return nil
    }
    
    internal func toJSValue(context: JSContext) -> JSValue? {
        // Create the base error object
        let errorValue = JS_NewError(context.ref)
        
        // Set the message if we have it
        if let message = self.message {
            let messageAtom = JS_NewAtom(context.ref, "message")
            let messageValue = JS_NewString(context.ref, message)
            JS_SetProperty(context.ref, errorValue, messageAtom, messageValue)
            JS_FreeAtom(context.ref, messageAtom)
        }
        
        // Set the name if we have it
        if let name = self.name {
            let nameAtom = JS_NewAtom(context.ref, "name")
            let nameValue = JS_NewString(context.ref, name)
            JS_SetProperty(context.ref, errorValue, nameAtom, nameValue)
            JS_FreeAtom(context.ref, nameAtom)
        }
        
        // Set the cause if we have it
        if let cause = self.cause {
            let causeAtom = JS_NewAtom(context.ref, "cause")
            let causeValue = JS_NewString(context.ref, cause)
            JS_SetProperty(context.ref, errorValue, causeAtom, causeValue)
            JS_FreeAtom(context.ref, causeAtom)
        }
        
        // Set the stack if we have it
        if let stack = self.stack {
            let stackAtom = JS_NewAtom(context.ref, "stack")
            let stackValue = JS_NewString(context.ref, stack)
            JS_SetProperty(context.ref, errorValue, stackAtom, stackValue)
            JS_FreeAtom(context.ref, stackAtom)
        }
        
        return errorValue
    }
    
    
    public var string: String {
        return """
        Javascript Error:
          Error: \(name ?? "unknown"), \(message ?? "unknown")
          Cause: \(cause ?? "unknown")
          Stack: \n\(stack ?? "unknown")
        """
    }
    
    static func from(_ error: Error) -> JSError {
        return JSError(message: error.localizedDescription)
    }
    
    internal init(value: JSValue, context: JSContext) {
        name = Self.value(for: "name", object: value, context: context)
        message = Self.value(for: "message", object: value, context: context)
        // TODO: cause can sometimes be an error, which makes the output look funky.  Fix it.
        cause = Self.value(for: "cause", object: value, context: context)
        stack = Self.value(for: "stack", object: value, context: context)
    }
    
    internal init(name: String? = "Native Code Exception", message: String?, cause: String? = nil, stack: String? = nil) {
        self.name = name
        self.message = message
        self.cause = cause
        self.stack = stack
    }
    
    internal let name: String?
    internal let message: String?
    internal let cause: String?
    internal let stack: String?
    
    internal static func value(for name: String, object: JSValue, context: JSContext) -> String? {
        let v = JS_GetPropertyStr(context.ref, object, name)
        let value = v.toJSConvertible(context: context)
        v.free(context)
        return value?.jsDescription()
    }
    
    public var description: String {
        return string
    }
    
    public var debugDescription: String {
        return string
    }
}
