//
//  File.swift
//  
//
//  Created by Brandon Sneed on 6/3/22.
//

import Foundation

#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

// Allow us to throw descriptive strings as errors.
extension String: LocalizedError {
    public var errorDescription: String? { return self }
}


internal extension String {
    static func from(jsString: JSStringRef) -> String? {
        return String(utf16CodeUnits: JSStringGetCharactersPtr(jsString), count: JSStringGetLength(jsString))
    }
    
    var jsString: JSStringRefWrapper? {
        return JSStringRefWrapper(value: self)
    }
}

extension JSConvertible {
    public func typed<T: JSConvertible>(_ type: T.Type) -> T? {
        // if it's a double, we need to do some gymnastics to get it into the
        // requested type, like int/uint/float.
        switch T.self {
        case _ as Int.Type:
            if let d = self as? Double { return Int(d) as? T }
        case _ as UInt.Type:
            if let d = self as? Double { return UInt(d) as? T }
        case _ as Float.Type:
            if let d = self as? Double { return Float(d) as? T }
        default:
            break
        }
        return self as? T
    }
}

extension JavascriptEngineError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .bundleNotFound:
            return "Bundle not found."
        case .unableToLoad:
            return "Unable to load bundle."
        case .unknownError(let e):
            return "Unknown Error: \(e)"
        case .evaluationError(let e):
            return e.description
        case .extensionFailed:
            return "Failed to extend class."
        }
    }
}

extension JavascriptClass {
    public init(context: JSContext, params: [JSPrimitive]?) throws {
        guard let params = params else { try self.init(context: context, params: nil); return }
        let p = params.map { $0.value }
        try self.init(context: context, params: p)
    }
}

extension JSExport {
    public func jsValue(context: JSContext) -> JSPrimitive {
        var result: JSPrimitive
        do {
            result = try JSObject(context: context, instance: self)
        } catch {
            result = context.undefined
        }
        return result
    }
}

extension JavascriptProperty {
    internal func addProperty(name: String, to object: JSObject) {
        object.addProperty(name: name) { context, this in
            let instance = this?.instance as? JavascriptClass
            return self.get(instance, this)?.jsValue(context: context) ?? context.undefined
        } setter: { context, this, value in
            if let s = self.set, let v = value {
                let instance = this?.instance as? JavascriptClass
                s(instance, this, v.value)
                return true
            }
            return false
        }
    }
}

extension JavascriptMethod {
    internal func addMethod(name: String, to object: JSObject) {
        object.addMethod(name: name) { context, this, params in
            let instance = this?.instance as? JavascriptClass
            let p = params.map { $0.value }
            let r = self.function(instance, this, p)?.jsValue(context: context)
            return r ?? context.undefined
        }
    }
}
