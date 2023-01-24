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

public protocol JSStatic {
    static func staticInit()
}

public protocol JSConvertible {
    static func from(jsValue: JSValueRef, context: JSContextRef) -> Self?
    func jsValue(context: JSContextRef) -> JSValueRef?
    var string: String { get }
}

extension JSConvertible {
    public func typed<T: JSConvertible>() -> T? {
        return self as? T
    }
}

public struct JSProperty {
    let getter: JSPropertyGetter
    let setter: JSPropertySetter?
}

public typealias JSPropertyGetter = () -> JSConvertible?
public typealias JSPropertySetter = (JSConvertible?) -> Void
public typealias JSFunctionDefinition = ([JSConvertible?]) -> JSConvertible?

extension Array where Element == JSConvertible? {
    public func typed<T: JSConvertible>(_ type: T.Type, index: Int) -> T? {
        guard index < count else { return nil }
        let result = self[index] as? T
        return result
    }
    
    public func index(_ index: Int) -> JSConvertible? {
        guard index < count else { return nil }
        return self[index]
    }
}

internal struct JSExportInfo {
    let type: JSExport.Type?
    let jsClassRef: JSClassRef?
    let instance: JSExport?
    let callback: JSFunctionDefinition?
}

