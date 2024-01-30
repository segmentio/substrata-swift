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

public typealias JSPropertyGetterDefinition = () -> JSConvertible?
public typealias JSPropertySetterDefinition = (JSConvertible?) -> Void

public class JSProperty {
    internal let getter: JSPropertyGetterDefinition
    internal let setter: JSPropertySetterDefinition?
    
    init(getter: @escaping JSPropertyGetterDefinition, setter: JSPropertySetterDefinition?) {
        self.getter = getter
        self.setter = setter
    }
}

open class JSExport {
    static let exportLock = NSLock()
    
    // Class stuff
    
    static private var _exportedMethods = [String: JSFunctionDefinition]()
    static internal var exportedMethods: [String: JSFunctionDefinition] {
        exportLock.lock()
        defer { exportLock.unlock() }
        return _exportedMethods
    }
    static public func exportMethod(named: String, function: @escaping JSFunctionDefinition) {
        exportLock.lock()
        defer { exportLock.unlock() }
        if _exportedMethods[named] != nil {
            /*#if DEBUG
            assertionFailure("This has already been exported!")
            #endif*/
            return
        }
        _exportedMethods[named] = function
    }
    
    static private var _exportedProperties = [String: JSProperty]()
    static internal var exportedProperties: [String: JSProperty] {
        exportLock.lock()
        defer { exportLock.unlock() }
        return _exportedProperties
    }
    static public func exportProperty(named: String, getter: @escaping JSPropertyGetterDefinition, setter: JSPropertySetterDefinition? = nil) {
        exportLock.lock()
        defer { exportLock.unlock() }
        if _exportedProperties[named] != nil {
            /*#if DEBUG
            assertionFailure("This has already been exported!")
            #endif*/
            return
        }
        _exportedProperties[named] = JSProperty(getter: getter, setter: setter)
    }
    
    // Instance stuff
    
    private var _exportedMethods = [String: JSFunctionDefinition]()
    internal var exportedMethods: [String: JSFunctionDefinition] {
        Self.exportLock.lock()
        defer { Self.exportLock.unlock() }
        return _exportedMethods
    }
    public func exportMethod(named: String, function: @escaping JSFunctionDefinition) {
        Self.exportLock.lock()
        defer { Self.exportLock.unlock() }
        if _exportedMethods[named] != nil {
            #if DEBUG
            assertionFailure("This has already been exported!")
            #endif
            return
        }
        _exportedMethods[named] = function
    }
    
    private var _exportedProperties = [String: JSProperty]()
    internal var exportedProperties: [String: JSProperty] {
        Self.exportLock.lock()
        defer { Self.exportLock.unlock() }
        return _exportedProperties
    }
    public func exportProperty(named: String, getter: @escaping JSPropertyGetterDefinition, setter: JSPropertySetterDefinition? = nil) {
        Self.exportLock.lock()
        defer { Self.exportLock.unlock() }
        if _exportedProperties[named] != nil {
            #if DEBUG
            assertionFailure("This has already been exported!")
            #endif
            return
        }
        _exportedProperties[named] = JSProperty(getter: getter, setter: setter)
    }
    
    // Overrides
    
    public required init() {
        
    }
    
    public func construct(args: [JSConvertible?]) {
        
    }
}
