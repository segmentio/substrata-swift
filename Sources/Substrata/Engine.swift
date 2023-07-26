//
//  Engine.swift
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

struct JSClassInfo {
    let classRef: JSClassRef
    let nativeType: JSExport.Type
}

var JSExportClass = [JSObjectRef: JSClassInfo]()

public class JSEngine {
    private let contextGroup: JSContextGroupRef
    private let globalContext: JSGlobalContextRef
    private let globalObject: JSContextRef
    private var exception: JSValueRef? {
        didSet {
            guard let e = exception else { return }
            if let callback = exceptionHandler {
                if let v = valueRefToType(context: globalContext, value: e) as? JSError {
                    callback(v)
                }
            }
            exception = nil
        }
    }
    
    private var exposedClasses = [String: JSClassRef]()
    private var exposedFunctions = [String: JSClassRef]()
    
    private let jsQueue = DispatchQueue(label: "com.segment.serial.javascript")

    public typealias BundleLoaded = (Bool) -> Void
    public var exceptionHandler: ((JSError) -> Void)?
    
    public var bridge: JSDataBridge? = nil
    
    public init() {
        contextGroup = JSContextGroupCreate()
        globalContext = JSGlobalContextCreateInGroup(contextGroup, nil)
        globalObject = JSContextGetGlobalObject(globalContext)
        
        setupProvidedObjects()
        
        jsQueue.async {
            self.bridge = JSDataBridge(engine: self)
        }
    }
    
    deinit {
        for classRef in exposedClasses.values {
            JSClassRelease(classRef)
        }
        for classRef in exposedFunctions.values {
            JSClassRelease(classRef)
        }
        JSContextGroupRelease(contextGroup)
        JSGlobalContextRelease(globalContext)
    }
    
    public func loadBundle(url: URL, completion: BundleLoaded? = nil) {
        var jsError: Bool = false
        
        if url.isFileURL == false || FileManager.default.fileExists(atPath: url.path) == false {
            jsError = false
            completion?(jsError)
            return
        }

        var jsSource: String? = nil
        do {
            jsSource = try String(contentsOf: url)
            if jsSource == nil {
                jsError = false
            }
        } catch {
            jsError = false
        }
            
        if let jsSource = jsSource {
            evaluate(script: jsSource)
        }
        
        completion?(jsError)
    }
    
    @discardableResult
    public func evaluate(script: String) -> JSConvertible? {
        var result: JSConvertible? = nil
        jsQueue.sync {
            let script = JSStringRefWrapper(value: script)
            let value = JSEvaluateScript(globalContext, script.ref, nil, nil, 0, &exception)
            result = valueRefToType(context: globalContext, value: value)
        }
        return result
    }
    
    public func export(type: JSExport.Type, className: String) {
        guard exposedClasses[className] == nil else { return }
        jsQueue.sync {
            let context = globalContext
            let classRef = genericClassCreate(type, name: className)
            exposedClasses[className] = classRef
            
            let info: UnsafeMutablePointer<JSExportInfo> = .allocate(capacity: 1)
            info.initialize(to: JSExportInfo(type: type, jsClassRef: classRef, instance: nil, callback: nil))
            //let classObject = JSObjectMake(context, classRef, info)!
            let classObject = JSObjectMakeConstructor(context, classRef, class_constructor)!
            /*let canSetPrivate = JSObjectSetPrivate(classObject, info)
            if canSetPrivate == false {
                print("JSObjectSetPrivate failed on \(className)")
            }*/
            
            JSExportClass[classObject] = JSClassInfo(classRef: classRef, nativeType: type)
            
            if let t = type as? JSStatic.Type {
                t.staticInit()
            }
            
            //print("updating prototype for class \(String(describing: info.pointee.type))")
            updatePrototype(object: classObject, context: context, properties: type.exportProperties, methods: type.exportMethods)
            let name = JSStringRefWrapper(value: className)
            JSObjectSetProperty(context, globalObject, name.ref, classObject, JSPropertyAttributes(kJSPropertyAttributeNone), &exception)
        }
    }
    
    @discardableResult
    public func export(instance: JSExport, className: String, variableName: String) -> JSExport? {
        var result: JSExport? = nil
        var classRef: JSClassRef? = nil
        // is the class type exported already?
        jsQueue.sync {
            classRef = exposedClasses[className]
        }
        if classRef == nil {
            // if not, export it first.
            export(type: type(of: instance.self), className: className)
        }
        // now set up the instance.
        jsQueue.sync {
            let context = globalContext
            guard let classRef = exposedClasses[className] else { return }
            let info: UnsafeMutablePointer<JSExportInfo> = .allocate(capacity: 1)
            info.initialize(to: JSExportInfo(type: type(of: instance.self), jsClassRef: classRef, instance: instance, callback: nil))
            
            let newObject = JSObjectMake(context, classRef, info)
            let propertyName = JSStringRefWrapper(value: variableName)
            JSObjectSetProperty(context, globalObject, propertyName.ref, newObject, JSPropertyAttributes(kJSPropertyAttributeNone), &exception)
            instance.valueRef = newObject
            result = instance
            
            let methods = instance.exportMethods
            for (key, value) in methods {
                let name = JSStringRefWrapper(value: key)
                let functionRef = genericFunctionCreate(value)
                let info: UnsafeMutablePointer<JSExportInfo> = .allocate(capacity: 1)
                info.initialize(to: JSExportInfo(type: nil, jsClassRef: functionRef, instance: nil, callback: value))
                let functionObject = JSObjectMake(context, functionRef, nil)
                JSObjectSetPrivate(functionObject, info)
                JSObjectSetProperty(context, newObject, name.ref, functionObject, JSPropertyAttributes(kJSPropertyAttributeNone), nil)
            }
        }
        return result
    }

    @discardableResult
    public func export(function: @escaping JSFunctionDefinition, named: String) -> JSFunction? {
        guard exposedFunctions[named] == nil else { return nil }
        var result: JSFunction? = nil
        jsQueue.sync {
            let context = globalContext
            let classRef = genericFunctionCreate(function)
            exposedFunctions[named] = classRef
            let classObject = JSObjectMake(context, classRef, nil)
            
            let info: UnsafeMutablePointer<JSExportInfo> = .allocate(capacity: 1)
            info.initialize(to: JSExportInfo(type: nil, jsClassRef: classRef, instance: nil, callback: function))
            JSObjectSetPrivate(classObject, info)
            
            let globalObject = JSContextGetGlobalObject(context)
            let name = JSStringRefWrapper(value: named)
            JSObjectSetProperty(context, globalObject, name.ref, classObject, JSPropertyAttributes(kJSPropertyAttributeNone), &exception)
            
            result = JSFunction(function: classObject)
        }
        return result
    }

    public func value(for keyPath: String) -> JSConvertible? {
        guard keyPath.count > 0 else { return nil }
        var result: JSConvertible? = nil
        let value = rawEvaluate(script: keyPath)
        jsQueue.sync {
            result = valueRefToType(context: globalContext, value: value)
        }
        return result
    }
    
    @discardableResult
    public func setValue(for keyPath: String, value: JSConvertible?) -> Bool {
        var result: Bool = false
        guard keyPath.count > 0 else { return result }
        var components = keyPath.components(separatedBy: ".")
        guard let last = components.last else { return result }
        components.removeLast()
        let path = components.joined(separator: ".")
        var pathValue = rawEvaluate(script: path)
        jsQueue.sync {
            if JSValueIsUndefined(globalContext, pathValue) {
                pathValue = globalObject
            }
            let propertyName = JSStringRefWrapper(value: last)
            JSObjectSetProperty(globalContext, pathValue, propertyName.ref, jsTyped(value, context: globalContext), JSPropertyAttributes(kJSPropertyAttributeNone), &exception)
            result = true
        }
        return result
    }
    
    @discardableResult
    public func call(functionName: String, args: [JSConvertible?]) -> JSConvertible? {
        var result: JSConvertible? = nil
        if let value = rawEvaluate(script: functionName) {
            jsQueue.sync {
                let args = args.map { jsTyped($0, context: self.globalContext) }
                let v = JSObjectCallAsFunction(globalContext, value, nil, args.count, args.isEmpty ? nil : args, &exception)
                result = valueRefToType(context: globalContext, value: v)
            }
        }
        return result
    }
    
    @discardableResult
    public func call(function: JSFunction?, args: [JSConvertible?]) -> JSConvertible? {
        var result: JSConvertible? = nil
        if let value = function?.function {
            jsQueue.sync {
                let args = args.map { jsTyped($0, context: self.globalContext) }
                let v = JSObjectCallAsFunction(globalContext, value, nil, args.count, args.isEmpty ? nil : args, &exception)
                result = valueRefToType(context: globalContext, value: v)
            }
        }
        return result
    }
}

// MARK: - Internals

extension JSEngine {
    @discardableResult
    internal func rawEvaluate(script: String) -> JSValueRef? {
        var result: JSValueRef? = nil
        jsQueue.sync {
            let script = JSStringRefWrapper(value: script)
            result = JSEvaluateScript(globalContext, script.ref, nil, nil, 0, &exception)
        }
        return result
    }
    
    internal func setupProvidedObjects() {
        export(type: Console.self, className: "console")
        evaluate(script: "var \(JSDataBridge.dataBridgeKey) = {};")
    }
}
