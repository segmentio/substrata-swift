//
//  File.swift
//  
//
//  Created by Brandon Sneed on 5/26/22.
//

import Foundation
#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

public class JSObject: JSPrimitive {
    public override var value: JSConvertible? {
        // is it a native instance?
        if let i = self.instance { return i }
        // is it a js class instance or function?
        if className != "Object" && !JSObjectIsFunction(context.ref, ref) {
            return JavascriptValue(self)
        }
        // guess it's a dictionary, gtfo.
        var result = [String: JSConvertible]()
        for prop in properties {
            if let v = self[prop].value {
                result[prop] = v
            }
        }
        return result as [String: JSConvertible]
    }
    
    public override func jsDescription() -> String? {
        if isError {
            if let s = call(method: "toString", params: []).value(String.self) {
                return s
            }
        }
        return nil
    }
    
    public convenience init(context: JSContext, type: JSExport.Type) throws {
        guard context.hasProperty(type.className) == false else {
             throw "\(type.className) is already defined as a type."
        }

        let info: UnsafeMutablePointer<JSExportInfo> = .allocate(capacity: 1)
        info.initialize(to: JSExportInfo(context: context, type: type))
        
        let className = type.className

        let classRef: JSClassRef = className.withCString { cName in
            var def = JSClassDefinition()
            def.className = cName
            def.finalize = class_finalize
            def.callAsConstructor = class_constructor
            def.hasInstance = class_instanceof
            def.getProperty = property_getter
            def.setProperty = property_setter

            // release will be handled by the context so we can re-use definitions.
            let classRef: JSClassRef = JSClassCreate(&def)
            return classRef
        }

        context.registeredClasses[className] = classRef
        let object = JSObjectMake(context.ref, classRef, info)!
        self.init(context: context, ref: object)
        
        if let jsClass = type.self as? JavascriptClass.Type {
            let staticProps = jsClass.staticProperties
            let staticMethods = jsClass.staticMethods
            
            staticProps.forEach { key, property in
                property.addProperty(name: key, to: self)
            }
            
            staticMethods.forEach { key, method in
                method.addMethod(name: key, to: self)
            }
        }

        context[className] = self
        self["prototype"] = [String: Any]().jsValue(context: context)
        JSObjectSetPrivate(object, info)
    }
    
    public convenience init(context: JSContext, instance: JSExport) throws {
        let type = type(of: instance)
        guard let classRef = context.registeredClasses[type.className] else {
             throw "\(type.className) has not been defined, unable to make an instance."
        }

        let info: UnsafeMutablePointer<JSExportInfo> = .allocate(capacity: 1)
        info.initialize(to: JSExportInfo(context: context, type: type))
        info.pointee.instance = instance

        self.init(context: context, ref: JSObjectMake(context.ref, classRef, info))
        
        if let jsInstance = instance as? JavascriptClass {
            let props = jsInstance.instanceProperties
            let methods = jsInstance.instanceMethods
            
            props.forEach { key, property in
                property.addProperty(name: key, to: self)
            }
            
            methods.forEach { key, method in
                method.addMethod(name: key, to: self)
            }
        }
    }
}

extension JSObject {
    public subscript(property: String) -> JSPrimitive {
        get {
            let property = JSStringRefWrapper(value: property)
            if let result = JSObjectGetProperty(context.ref, ref, property.ref, nil) {
                return JSPrimitive.construct(from: result, context: context)
            } else {
                return context.undefined
            }
        }
        set {
            let property = JSStringRefWrapper(value: property)
            JSObjectSetProperty(context.ref, ref, property.ref, newValue.ref, 0, nil)
        }
    }
    
    public var properties: [String] {
        let names = JSObjectCopyPropertyNames(context.ref, ref)
        defer { JSPropertyNameArrayRelease(names) }
        
        let count = JSPropertyNameArrayGetCount(names)
        let list = (0..<count).map { JSPropertyNameArrayGetNameAtIndex(names, $0)! }
        
        var result = [String]()
        for item in list {
            if let s = String.from(jsString: item) { result.append(s) }
        }
        return result
    }
    
    @discardableResult
    public func removeProperty(_ property: String) -> Bool {
        let property = JSStringRefWrapper(value: property)
        return JSObjectDeleteProperty(context.ref, ref, property.ref, &context.exception)
    }

    public func hasProperty(_ property: String) -> Bool {
        let property = JSStringRefWrapper(value: property)
        return JSObjectHasProperty(context.ref, ref, property.ref)
    }
}


extension JSObject {
    public func call(this: JSObject? = nil, params: [JSPrimitive]) -> JSPrimitive {
        let result = JSObjectCallAsFunction(context.ref, ref, this?.ref, params.count, params.isEmpty ? nil : params.map { $0.ref }, nil)
        return JSPrimitive.construct(from: result, context: context)
    }

    public func call(method: String, params: [JSPrimitive]) -> JSPrimitive {
        if let method = self[method] as? JSFunction {
            let result = method.call(this: self, params: params)
            return result
        }
        return context.undefined
    }
}

extension JSObject {
    public var className: String {
        let constructor = self["constructor"].typed(JSFunction.self)
        if let name = constructor?["name"].value(String.self) {
            return name
        }
        return "Object"
    }
    
    public var instance: JSExport? {
        guard let privateData = privateData else { return nil }
        return privateData.instance as? JSExport
    }
    
    internal var hasPrivateData: Bool {
        let ptr = JSObjectGetPrivate(ref)
        if ptr != nil { return true }
        return false
    }
    
    internal var privateData: JSExportInfo? {
        get {
            guard hasPrivateData else { return nil }
            let info = JSObjectGetPrivate(ref).assumingMemoryBound(to: JSExportInfo.self)
            return info.pointee
        }
        set {
            guard hasPrivateData else { return }
            guard let newValue = newValue else { return }
            let info: UnsafeMutablePointer<JSExportInfo> = .allocate(capacity: 1)
            info.initialize(to: newValue)
            JSObjectSetPrivate(ref, info)
        }
    }
}


extension Dictionary: JSConvertible where Key == String {
    public func jsValue(context: JSContext) -> JSPrimitive {
        guard let ref = JSObjectMake(context.ref, nil, nil) else { return context.undefined }
        for (key, value) in self {
            if let v = value as? JSConvertible {
                let jsString = JSStringRefWrapper(value: key)
                let prop = jsString.ref
                JSObjectSetProperty(context.ref, ref, prop, v.jsValue(context: context).ref, 0, &context.exception)
            }
        }
        let result = JSPrimitive.construct(from: ref, context: context)
        return result
    }
}

extension NSDictionary: JSConvertible {
    public func jsValue(context: JSContext) -> JSPrimitive {
        guard let ref = JSObjectMake(context.ref, nil, nil) else { return context.undefined }
        for (key, value) in self {
            if let v = value as? JSConvertible {
                let jsString = JSStringRefWrapper(value: key as! String)
                let prop = jsString.ref
                JSObjectSetProperty(context.ref, ref, prop, v.jsValue(context: context).ref, 0, &context.exception)
            }
        }
        let result = JSPrimitive.construct(from: ref, context: context)
        return result
    }
}
