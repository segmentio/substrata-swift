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
    private static var bookKeeping = [JSObjectRef: JSClassInfo]()
    
    internal static var exportProperties = [String: JSProperty]()
    internal static var exportMethods = [String: JSFunctionDefinition]()
    internal var exportProperties = [String: JSProperty]()
    internal var exportMethods = [String: JSFunctionDefinition]()
    internal var valueRef: JSValueRef? = nil
    public required init() { }
    open func construct(args: [JSConvertible]) { }
}

extension JSExport {
    /*
     This lock is shared between instances obviously.  The same object can be exported
     to different engines, across threads, etc.  We can't store our data in the VM so
     we're left to our own devices.
     */
    static let lock = NSLock()
    
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
