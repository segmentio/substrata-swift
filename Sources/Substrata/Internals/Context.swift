//
//  File.swift
//  
//
//  Created by Brandon Sneed on 1/22/24.
//

import Foundation
import SubstrataQuickJS

internal class JSContext {
    internal var ref: JSContextRef
    internal var runtimeRef: JSRuntimeRef
    
    private let exportLock = Lock()
    private let executionLock = RecursiveLock()
    
    private var classCounter: Int32 = 0
    private var functionCounter: Int32 = 0
    private var methodCounter: Int32 = 0
    private var propertyCounter: Int32 = 0
    
    internal var classes = [Int32: JSClassInfo]()
    internal var functions = [Int32: JSFunctionDefinition]()
    internal var propertyGetters = [Int32: JSPropertyGetterDefinition]()
    internal var propertySetters = [Int32: JSPropertySetterDefinition]()
    internal var methodIDs = [Int32: String]()
    
    internal var builtIns: Builtins?
    internal let globalRef: JSValue
    internal var exceptionHandler: ((JSError) -> Void)?
    
    private var shuttingDown = false
    private var executing = false
    
    init(runtime: JSRuntimeRef) {
        self.ref = JS_NewContext(runtime)
        self.globalRef = JS_GetGlobalObject(ref)
        self.runtimeRef = runtime
        ref.opaqueContext = self
    }
    
    var isShuttingDown: Bool {
        return exportLock.perform {
            return shuttingDown
        }
    }
    
    func shutdown() {
        exportLock.perform {
            shuttingDown = true
        }
        
        executionLock.perform {
            builtIns?.free()
            
            ref.opaqueContext = nil
            globalRef.free(self)
            JS_FreeContext(ref)
            
            // make sure everything gets dropped;
            // we have a completely non-functional js engine now,
            // and can't have any leaks happening from object tracking.
            classes.removeAll()
            functions.removeAll()
            propertyGetters.removeAll()
            propertySetters.removeAll()
            methodIDs.removeAll()
        }
    }
}

extension JSContext {
    func throwError(_ error: Error) -> JSValue {
        let jsError = JSError.from(error)
        if let errorValue = jsError.toJSValue(context: self) {
            return JS_Throw(self.ref, errorValue)
        }
        return JS_Throw(self.ref, JS_NewError(self.ref))
    }
}

extension JSContext {
    func newContextClassID() -> Int32 {
        return exportLock.perform {
            let new = classCounter
            classCounter += 1
            return new
        }
    }
    
    func newContextFunctionID() -> Int32 {
        return exportLock.perform {
            let new = functionCounter
            functionCounter += 1
            return new
        }
    }
    
    func newMethodID() -> Int32 {
        return exportLock.perform {
            let new = methodCounter
            methodCounter += 1
            return new
        }
    }
    
    func newPropertyID() -> Int32 {
        return exportLock.perform {
            let new = propertyCounter
            propertyCounter += 1
            return new
        }
    }
}

extension JSContext {
    func performThreadSafe(closure: () -> Void) {
        if !isShuttingDown {
            return executionLock.perform {
                return closure()
            }
        }
    }
}

extension JSContext {
    func addExport(functionID: Int32, value: @escaping JSFunctionDefinition) {
        exportLock.perform {
            if functions[functionID] != nil { return }
            functions[functionID] = value
        }
    }
    
    func findExport(functionID: Int32) -> JSFunctionDefinition? {
        return exportLock.perform {
            return functions[functionID]
        }
    }
    
    func addExport(propertyID: Int32, value: @escaping JSPropertyGetterDefinition) {
        exportLock.perform {
            if propertyGetters[propertyID] != nil { return }
            propertyGetters[propertyID] = value
        }
    }
    
    func findExport(propertyID: Int32) -> JSPropertyGetterDefinition? {
        return exportLock.perform {
            return propertyGetters[propertyID]
        }
    }
    
    func addExport(propertyID: Int32, value: @escaping JSPropertySetterDefinition) {
        exportLock.perform {
            if propertySetters[propertyID] != nil { return }
            propertySetters[propertyID] = value
        }
    }
    
    func findExport(propertyID: Int32) -> JSPropertySetterDefinition? {
        return exportLock.perform {
            return propertySetters[propertyID]
        }
    }
    func addExport(classID: Int32, value: JSClassInfo) {
        exportLock.perform {
            if classes[classID] != nil { return }
            classes[classID] = value
        }
    }
    
    func findExport(classID: Int32) -> JSClassInfo? {
        return exportLock.perform {
            return classes[classID]
        }
    }
    
    func findExport(classType: JSExport.Type) -> JSClassInfo? {
        return exportLock.perform {
            // there's enough guards elsewhere to make sure there's only one match.
            let found = classes.filter { key, classInfo in
                return classInfo.type == classType
            }
            return found.first?.value
        }
    }
    
    func addExport(methodID: Int32, name: String) {
        exportLock.perform {
            methodIDs[methodID] = name
        }
    }
    
    func findExport(methodID: Int32) -> String? {
        return exportLock.perform {
            return methodIDs[methodID]
        }
    }
}

