//
//  File.swift
//  
//
//  Created by Brandon Sneed on 1/14/24.
//

import Foundation
import SubstrataQuickJS

public protocol JSConvertible: CustomStringConvertible, CustomDebugStringConvertible { }

extension JSConvertible {
    public func typed<T: JSConvertible>() -> T? {
        if let s = self as? T { return s }
        // special handling for UInt/Float since JS deals in double's and int's.
        if let s = self as? Int, T.self is UInt.Type { return UInt(s) as? T }
        if let s = self as? Double, T.self is Float.Type { return Float(s) as? T }
        return nil
    }
    
    public func typed<T: JSConvertible>(as: T.Type) -> T? {
        if let s = self as? T { return s }
        // special handling for UInt/Float since JS deals in double's and int's.
        if let s = self as? Int, T.self is UInt.Type { return UInt(s) as? T }
        if let s = self as? Double, T.self is Float.Type { return Float(s) as? T }
        return nil
    }
}

public typealias JSFunctionDefinition = ([JSConvertible?]) -> JSConvertible?

public protocol JSStatic {
    static func staticInit()
}

open class JSExport {
    static let exportLock = NSLock()
    static private var _exportedMethods = [String: JSFunctionDefinition]()
    static internal var exportedMethods: [String: JSFunctionDefinition] {
        exportLock.lock()
        defer { exportLock.unlock() }
        return _exportedMethods
    }
    static public func exportMethod(named: String, function: @escaping JSFunctionDefinition) {
        exportLock.lock()
        _exportedMethods[named] = function
        exportLock.unlock()
    }

    private var _exportedMethods = [String: JSFunctionDefinition]()
    internal var exportedMethods: [String: JSFunctionDefinition] {
        Self.exportLock.lock()
        defer { Self.exportLock.unlock() }
        return _exportedMethods
    }
    public func exportMethod(named: String, function: @escaping JSFunctionDefinition) {
        Self.exportLock.lock()
        _exportedMethods[named] = function
        Self.exportLock.unlock()
    }
    
    public required init() {
        
    }
    
    public func construct(args: [JSConvertible?]) {
        
    }
}
