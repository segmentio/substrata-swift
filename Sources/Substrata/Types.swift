//
//  Types.swift
//
//
//  Created by Brandon Sneed on 4/11/22.
//

import Foundation

/// Error handling for the Javascript Engine.
public typealias JavascriptErrorHandler = (JavascriptEngineError) -> ()

/**
 Conformance to JavascriptEngine can enable support for other
 JS runtimes, such as J2V8, Hermes, etc.
 */
public protocol JavascriptEngine {
    typealias BundleLoaded = (JavascriptEngineError?) -> Void
    
    var errorHandler: JavascriptErrorHandler? { get set }
    var bridge: JavascriptDataBridge? { get }
    
    func loadBundle(url: URL, completion: BundleLoaded?)
    
    func object(key: String) -> JSConvertible?
    func setObject(key: String, value: JSConvertible)
    func expose(name: String, classType: JavascriptClass.Type) throws
    func expose(name: String, function: @escaping JavascriptFunction) throws
    func extend(name: String, object: String, function: @escaping JavascriptFunction) throws
    func call(functionName: String, params: JSConvertible?...) -> JSConvertible?
    func evaluate(script: String) -> JSConvertible?
}

public protocol JavascriptDataBridge {
    subscript(key: String) -> JSConvertible? { get set }
}

@frozen
public enum JavascriptEngineError: Error {
    /// Unable to find the JS bundle.
    case bundleNotFound
    /// Unable to load the bundle due.
    case unableToLoad
    /// An unknown error occurred, see Error.
    case unknownError(Error)
    /// An evaluation error occurred, see String for details.
    case evaluationError(JSError)
    /// An attempt to extend an existing object failed.
    case extensionFailed
}

public typealias JavascriptFunction = (_ weakSelf: JavascriptClass?, _ this: JSObject?, _ params: JSConvertible?...) -> JSConvertible?

public typealias JavascriptPropertyGet = (_ weakSelf: JavascriptClass?, _ this: JSObject?) -> JSConvertible?
public typealias JavascriptPropertySet = (_ weakSelf: JavascriptClass?, _ this: JSObject?, _ value: JSConvertible?) -> ()

public struct JavascriptProperty {
    public let get: JavascriptPropertyGet
    public let set: JavascriptPropertySet?
    public init(get: @escaping JavascriptPropertyGet, set: @escaping JavascriptPropertySet) { self.get = get; self.set = set }
    public init(get: @escaping JavascriptPropertyGet) { self.get = get; self.set = nil }
}

public struct JavascriptMethod {
    public let function: JavascriptFunction
    public init(_ function: @escaping JavascriptFunction) {
        self.function = function
    }
}

public protocol JavascriptClass: JSExport {
    static var className: String { get }
    static var staticProperties: [String: JavascriptProperty] { get }
    static var staticMethods: [String: JavascriptMethod] { get }
    var instanceProperties: [String: JavascriptProperty] { get }
    var instanceMethods: [String: JavascriptMethod] { get }
    init(context: JSContext, params: JSConvertible?...) throws
}

public struct JavascriptValue: JSConvertible {
    public let value: JSPrimitive
    public init(_ value: JSPrimitive) { self.value = value }
    public func jsValue(context: JSContext) -> JSPrimitive { return value }
}
