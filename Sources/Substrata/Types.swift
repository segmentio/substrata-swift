//
//  Types.swift
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

Codable

public protocol JSConvertible {
    static func from(jsValue: JSValueRef, context: JSContextRef) -> Self?
    func jsValue(context: JSContextRef) -> JSValueRef?
    var string: String { get }
}

extension JSConvertible {
    public func typed<T: JSConvertible>() -> T? {
        return self as? T
    }
    
    public func typed<T: JSConvertible>(as: T) -> T? {
        return self as? T
    }
}

public struct JSProperty {
    public let getter: JSPropertyGetter
    public let setter: JSPropertySetter?
    
    public init(getter: @escaping JSPropertyGetter, setter: JSPropertySetter?) {
        self.getter = getter
        self.setter = setter
    }
    
    public init(getter: @escaping JSPropertyGetter) {
         self.getter = getter
         self.setter = nil
     }
}

public typealias JSPropertyGetter = () -> JSConvertible?
public typealias JSPropertySetter = (JSConvertible?) -> Void
public typealias JSFunctionDefinition = ([JSConvertible]) -> JSConvertible?

extension Array where Element == JSConvertible {
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

internal struct JSExportInfo {
    let type: JSExport.Type?
    let jsClassRef: JSClassRef?
    let instance: JSExport?
    let callback: JSFunctionDefinition?
}

