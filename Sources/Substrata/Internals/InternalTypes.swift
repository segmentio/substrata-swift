//
//  File.swift
//  
//
//  Created by Brandon Sneed on 1/21/24.
//

import Foundation
import SubstrataQuickJS

internal typealias JSRuntimeRef = OpaquePointer
internal typealias JSContextRef = OpaquePointer

internal protocol JSInternalConvertible {
    static func fromJSValue(_ value: JSValue, context: JSContext) -> Self?
    func toJSValue(context: JSContext) -> JSValue?
    var string: String { get }
    func jsDescription() -> String
}

extension JSInternalConvertible {
    
}

extension JSInternalConvertible {
    public var description: String { return string }
    public var debugDescription: String { return string }
    public func jsDescription() -> String {
        return string
    }
}

internal class JSClassInfo {
    let name: String
    let type: JSExport.Type
    let classID: JSClassID
    var waitingToAttach: JSExport? = nil
    var methodNames = [Int32: String]()
    
    init(type: JSExport.Type, classID: JSClassID, name: String) {
        self.type = type
        self.classID = classID
        self.name = name
    }
}

internal class JSClassInstanceInfo {
    let classID: JSClassID
    let instance: JSExport?
    let type: JSExport.Type
    
    init(type: JSExport.Type, classID: JSClassID, instance: JSExport?) {
        self.type = type
        self.classID = classID
        self.instance = instance
    }
}

