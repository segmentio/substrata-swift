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

internal struct JSClassInfo {
    let classRef: JSClassRef
    let nativeType: JSExport.Type
}

public protocol JSStatic {
    static func staticInit()
}

open class JSExport {
    /*
     This lock is shared between instances obviously.  The same object can be exported
     to different engines, across threads, etc.  We can't store our data in the VM so
     we're left to our own devices.
     */
    private static let lock = NSLock()
    private static var bookKeeping = [JSObjectRef: JSClassInfo]()
    private static var exportProperties = [String: JSProperty]()
    private static var exportMethods = [String: JSFunctionDefinition]()
    private var exportProperties = [String: JSProperty]()
    private var exportMethods = [String: JSFunctionDefinition]()
    internal var valueRef: JSValueRef? = nil
    public required init() { }
    open func construct(args: [JSConvertible]) { }
}

extension JSExport {
    public static func exportedProperties() -> [String: JSProperty] {
        lock.lock()
        defer { lock.unlock() }
        return exportProperties
    }
    
    public func exportedProperties() -> [String: JSProperty] {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        return exportProperties
    }
    
    public static func exportedMethods() -> [String: JSFunctionDefinition] {
        lock.lock()
        defer { lock.unlock() }
        return exportMethods
    }
    
    public func exportedMethods() -> [String: JSFunctionDefinition] {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        return exportMethods
    }
}

extension JSExport {
    public static func export(property: JSProperty, as name: String) {
        lock.lock()
        Self.exportProperties[name] = property
        lock.unlock()
    }

    public static func export(method: @escaping JSFunctionDefinition, as name: String) {
        lock.lock()
        if Self.exportMethods[name] == nil {
            Self.exportMethods[name] = method
        }
        lock.unlock()
    }
    
    public func export(method: @escaping JSFunctionDefinition, as name: String) {
        Self.lock.lock()
        exportMethods[name] = method
        Self.lock.unlock()
    }
    
    public func export(property: JSProperty, as name: String) {
        Self.lock.lock()
        exportProperties[name] = property
        Self.lock.unlock()
    }
    
    internal static func addEntry(ref: JSObjectRef, classInfo: JSClassInfo) {
        Self.lock.lock()
        bookKeeping[ref] = classInfo
        Self.lock.unlock()
    }
    
    internal static func removeEntry(ref: JSObjectRef) {
        Self.lock.lock()
        bookKeeping.removeValue(forKey: ref)
        Self.lock.unlock()
    }
    
    internal static func getEntry(ref: JSObjectRef) -> JSClassInfo? {
        Self.lock.lock()
        defer {
            Self.lock.unlock()
        }
        return bookKeeping[ref]
    }
}

extension JSExport {
    public static func staticValues() -> UnsafePointer<JSStaticValue>? {
        /**
         This whole thing is broken somehow.  The memory is disappearing unexpectedly for
         either the property names, or the static values list.  It's hard to tell which/why, and
         if i could juse work with regular pointers instead of UnsafeWhatever it'd be done
         already, but i can't, so it's not. :D
         
         Will revisit in the future.  This means in the meantime, we don't support static
         properties, and people will have to do a static get/set functions instead.
         */
        
        return nil // until next time ...
        
        /*Self.lock.lock()
        defer { Self.lock.unlock() }
        let className = String(describing: Self.self)
        
        if exportProperties.count == 0 {
            return nil
        }
        
        if let statics = JSStaticPool.staticValues[className] {
            return UnsafePointer(statics.baseAddress)
        } else {
            var statics = [JSStaticValue]()
            for prop in exportProperties {
                let propName = strdup(prop.key)!
                
                // store the property name
                JSStaticPool.propertyNames[className] = [prop.key: propName]
                //JSStaticPool.propertyNames2[className] = [prop.key: s]
                
                let s = JSStaticValue(name: UnsafePointer(propName), getProperty: property_getter, setProperty: property_setter, attributes: 0)
                statics.append(s)
            }
            
            let x = UnsafeMutableBufferPointer<JSStaticValue>.allocate(capacity: statics.count)
            _ = x.initialize(from: statics)
            
            JSStaticPool.staticValues[className] = x
            
            print(JSStaticPool.staticValues)
            print(JSStaticPool.propertyNames)
            
            return UnsafePointer(x.baseAddress)
        }*/
    }
}

/**
 
 This is related to the function above.

internal class JSStaticPool {
    // classname->propertyName->pointer
    static var propertyNames = [String: [String: UnsafeMutablePointer<CChar>]]()
    // classname->pointer
    static var staticValues = [String: UnsafeMutableBufferPointer<JSStaticValue>]()
}

*/
