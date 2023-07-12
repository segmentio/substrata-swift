//
//  Exporting.swift
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

public class JSExport {
    //static let 
    internal var exportProperties = [String: JSProperty]()
    internal var exportMethods = [String: JSFunctionDefinition]()
    internal var valueRef: JSValueRef? = nil
    public required init() { }
    public func construct(args: [JSConvertible?]) { }
}

extension JSExport {
    static func export(method: @escaping JSFunctionDefinition, as name: String) {
        //exportMethods[name] = method
        let className = String(describing: Self.self)
        let classInfo = JSStaticStorage.lookup(className: className)
        classInfo.exportMethods[name] = method
    }
    
    static func export(property: JSProperty, as name: String) {
        //exportProperties[name] = property
        let className = String(describing: Self.self)
        let classInfo = JSStaticStorage.lookup(className: className)
        classInfo.exportProperties[name] = property
    }

    func export(method: @escaping JSFunctionDefinition, as name: String) {
        exportMethods[name] = method
    }
    
    func export(property: JSProperty, as name: String) {
        exportProperties[name] = property
    }
}

extension JSExport {
    internal static var exportProperties: [String: JSProperty] {
        let name = String(describing: Self.self)
        return JSStaticStorage.lookup(className: name).exportProperties
    }
    
    internal static var exportMethods: [String: JSFunctionDefinition] {
        let name = String(describing: Self.self)
        return JSStaticStorage.lookup(className: name).exportMethods
    }
}

internal class JSStaticStorage {
    internal class ClassInfo {
        internal var exportProperties = [String: JSProperty]()
        internal var exportMethods = [String: JSFunctionDefinition]()
    }
    
    internal static var lookup = [String: ClassInfo]()
    internal static func lookup(className: String) -> ClassInfo {
        var classInfo: ClassInfo
        if let found = JSStaticStorage.lookup[className] {
            classInfo = found
        } else {
            classInfo = JSStaticStorage.ClassInfo()
            lookup[className] = classInfo
        }
        return classInfo
    }
}
