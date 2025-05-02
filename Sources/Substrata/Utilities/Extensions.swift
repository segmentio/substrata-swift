//
//  File.swift
//  
//
//  Created by Brandon Sneed on 1/16/24.
//

import Foundation
import SubstrataQuickJS

extension JSContextRef {
    var opaqueContext: JSContext? {
        get {
            guard let ptr = JS_GetContextOpaque(self) else {
                return nil
            }
            return Unmanaged<JSContext>.fromOpaque(ptr).takeUnretainedValue()
        }
        set {
            if let jsContext = newValue {
                let ptr = Unmanaged<JSContext>.passUnretained(jsContext).toOpaque()
                JS_SetContextOpaque(self, ptr)
            } else {
                JS_SetContextOpaque(self, nil)
            }
        }
    }
}

extension JSAtom {
    static func fromString(_ str: String, context: JSContext) -> JSAtom {
        return JS_NewAtom(context.ref, str)
    }
}

extension SubstrataQuickJS.JSValue: Swift.Hashable {
    public static func == (lhs: JSValue, rhs: JSValue) -> Bool {
        return lhs.u.ptr == rhs.u.ptr
    }
    
    public func hash(into hasher: inout Hasher) {
        self.u.ptr.hash(into: &hasher)
    }
}

extension JSFunction: Hashable {
    public static func == (lhs: JSFunction, rhs: JSFunction) -> Bool {
        return lhs === rhs
    }
    
    public func hash(into hasher: inout Hasher) {
        self.value.u.ptr.hash(into: &hasher)
    }
}

extension JSClass: Hashable {
    public static func == (lhs: JSClass, rhs: JSClass) -> Bool {
        return lhs === rhs
    }
    
    public func hash(into hasher: inout Hasher) {
        self.value.u.ptr.hash(into: &hasher)
    }
}

extension JSValue {
    internal static var null: JSValue = {
        return JSValue(u: JSValueUnion(int32: Int32(JS_TAG_NULL)), tag: Int64(JS_TAG_NULL))
    }()

    internal static var undefined: JSValue = {
        return JSValue(u: JSValueUnion(int32: Int32(JS_TAG_UNDEFINED)), tag: Int64(JS_TAG_UNDEFINED))
    }()
    
    internal func free(_ context: JSContext?) {
        guard let context else { return }
        context.performThreadSafe {
            JS_FreeValue(context.ref, self)
        }
    }
    
    internal func hasProperty(context: JSContext?, string: String) -> Bool {
        guard let context else { return false }
        let atom = JS_NewAtom(context.ref, string)
        if atom != Constants.JS_ATOM_NULL {
            let result = JS_HasProperty(context.ref, self, atom) > 0
            JS_FreeAtom(context.ref, atom)
            return result
        }
        return false
    }
    
    @discardableResult
    internal func handlePossibleException(context: JSContext?) -> JSConvertible? {
        guard let context else { return nil }
        if JS_IsException(self) > 0 {
            // exceptions are different than errors, in that they're thrown.
            // to get the error from an exception, you work with the exception itself
            // rather than an error result.
            let exception = JS_GetException(context.ref)
            defer { exception.free(context) }
            
            let e = JSError(value: exception, context: context)
            if let exceptionHandler = context.exceptionHandler {
                exceptionHandler(e)
            } else {
                #if DEBUG
                assertionFailure(e.description)
                #endif
            }
            // pass the error back since it's gone now.
            return e
        }
        return nil
    }
    
    internal func toJSConvertible(context: JSContext?) -> JSConvertible? {
        guard let context else { return nil }

        let value = self
        
        if JS_IsUndefined(value) > 0 {
            return nil
        }
        
        if let error = handlePossibleException(context: context) {
            return error
        }
        
        // these rely on the conversion failing to make determinations.
        if let v = NSNull.fromJSValue(value, context: context) { return v }
        if let v = String.fromJSValue(value, context: context) { return v }
        if let v = Bool.fromJSValue(value, context: context) { return v }
        
        if JS_IsNumber(value) > 0 {
            // try to get the appropriate type back ...
            // JS has no notion of UInt, only Double/Int.
            if let d = Double.fromJSValue(value, context: context) {
                if d.isInteger {
                    return Int(d)
                } else {
                    return d
                }
            }
        }
        
        if let v = Array<JSConvertible>.fromJSValue(value, context: context) { return v }
        if let v = JSFunction.fromJSValue(value, context: context) { return v }
        if let v = JSError.fromJSValue(value, context: context) { return v }
        if let v = JSClass.fromJSValue(value, context: context) { return v }
        if let v = Dictionary<String, JSConvertible>.fromJSValue(value, context: context) { return v }
        
        return nil
    }
    
    internal func getFunctionName(_ context: JSContext?) -> String {
        guard let context else { return "<no context>" }
        if JS_IsFunction(context.ref, self) > 0 {
            let str = JS_GetPropertyStr(context.ref, self, "name")
            defer { str.free(context) }
            if let name = String.fromJSValue(str, context: context) {
                return name
            }
        }
        return "unknown"
    }
    
    internal func getClassName(_ context: JSContext?) -> String {
        guard let context else { return "<no context>" }
        if JS_IsObject(self) > 0 {
            if hasProperty(context: context, string: "constructor") {
                let const = JS_GetPropertyStr(context.ref, self, "constructor")
                defer { const.free(context) }
                return const.getFunctionName(context)
            }
        }
        return "Object"
    }
}

extension Double {
    internal var isInteger: Bool {
        return truncatingRemainder(dividingBy: 1) == 0
    }
}

extension String {
    internal init<T>(humanized instance: T?) {
        guard let i = instance else {
            self.init("nil")
            return
        }
        self.init(describing: i)
    }
}

extension Array where Element == JSConvertible? {
    public func typed<T: JSConvertible>(as type: T.Type, index: Int) -> T? {
        guard index < count else { return nil }
        let result = self[index] as? T
        if result is NSNull { return nil }
        return result
    }
    
    public func index(_ index: Int) -> JSConvertible? {
        guard index < count else { return nil }
        let result = self[index]
        if result is NSNull { return nil }
        return result
    }
}

extension Array where Element: Equatable {
    // Remove first collection element that is equal to the given `object`:
    mutating func remove(_ object: Element) {
        guard let index = firstIndex(of: object) else {return}
        remove(at: index)
    }
}

// Brought over from Decimal.swift; These methods are internal there, but we need them.
// see: https://github.com/apple/swift-corelibs-foundation/blob/cfac32b92d5fb62a651967cf22756352179b58ba/Sources/Foundation/Decimal.swift#L108
extension Decimal {
    fileprivate subscript(index: UInt32) -> UInt16 {
        get {
            switch index {
            case 0: return _mantissa.0
            case 1: return _mantissa.1
            case 2: return _mantissa.2
            case 3: return _mantissa.3
            case 4: return _mantissa.4
            case 5: return _mantissa.5
            case 6: return _mantissa.6
            case 7: return _mantissa.7
            default: fatalError("Invalid index \(index) for _mantissa")
            }
        }
        set {
            switch index {
            case 0: _mantissa.0 = newValue
            case 1: _mantissa.1 = newValue
            case 2: _mantissa.2 = newValue
            case 3: _mantissa.3 = newValue
            case 4: _mantissa.4 = newValue
            case 5: _mantissa.5 = newValue
            case 6: _mantissa.6 = newValue
            case 7: _mantissa.7 = newValue
            default: fatalError("Invalid index \(index) for _mantissa")
            }
        }
    }

    internal var doubleValue: Double {
        if _length == 0 {
            return _isNegative == 1 ? Double.nan : 0
        }

        var d = 0.0
        for idx in (0..<min(_length, 8)).reversed() {
            d = d * 65536 + Double(self[idx])
        }

        if _exponent < 0 {
            for _ in _exponent..<0 {
                d /= 10.0
            }
        } else {
            for _ in 0..<_exponent {
                d *= 10.0
            }
        }
        return _isNegative != 0 ? -d : d
    }
}

internal extension NSNumber {
    static let trueValue = NSNumber(value: true)
    static let trueObjCType = trueValue.objCType
    static let falseValue = NSNumber(value: false)
    static let falseObjCType = falseValue.objCType
    
    var type: CFNumberType {
        return CFNumberGetType(self as CFNumber)
    }
    
    func isBool() -> Bool {
        let type = self.objCType
        if (compare(NSNumber.trueValue) == .orderedSame && type == NSNumber.trueObjCType) ||
           (compare(NSNumber.falseValue) == .orderedSame && type == NSNumber.falseObjCType) {
            return true
        }
        return false
    }
    
    func isDouble() -> Bool {
        let type = self.type
        switch type {
        case .float32Type, .floatType, .float64Type, .doubleType:
            return true
        default:
            return false
        }
    }
}

