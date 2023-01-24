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

public class JSExport {
    internal static var exportProperties = [String: JSProperty]()
    internal static var exportMethods = [String: JSFunctionDefinition]()
    internal var exportProperties = [String: JSProperty]()
    internal var exportMethods = [String: JSFunctionDefinition]()
    internal var valueRef: JSValueRef? = nil
    public required init() { }
    public func construct(args: [JSConvertible?]) { }
}

extension JSExport {
    static func export(method: @escaping JSFunctionDefinition, as name: String) {
        exportMethods[name] = method
    }
    
    static func export(property: JSProperty, as name: String) {
        exportProperties[name] = property
    }

    func export(method: @escaping JSFunctionDefinition, as name: String) {
        exportMethods[name] = method
    }
    
    func export(property: JSProperty, as name: String) {
        exportProperties[name] = property
    }
}
