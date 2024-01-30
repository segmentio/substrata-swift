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
    
    private let exportLock = NSLock()
    private let executionQueue = DispatchQueue(label: "com.segment.serial.javascript")
    
    private var classCounter: Int32 = 0
    private var functionCounter: Int32 = 0
    private var methodCounter: Int32 = 0
    private var propertyCounter: Int32 = 0
    
    internal var classes = [Int32: JSClassInfo]()
    internal var functions = [Int32: JSFunctionDefinition]()
    internal var propertyGetters = [Int32: JSPropertyGetterDefinition]()
    internal var propertySetters = [Int32: JSPropertySetterDefinition]()
    internal var instances = [JSClassInstanceInfo]()
    internal var methodIDs = [Int32: String]()
    internal var activeValues = [JSRetainedValue]()
    
    internal var builtIns: Builtins?
    internal let globalRef: JSValue
    internal var exceptionHandler: ((JSError) -> Void)?
    
    private var shuttingDown = false
    
    init(runtime: JSRuntimeRef) {
        self.ref = JS_NewContext(runtime)
        self.globalRef = JS_GetGlobalObject(ref)
        self.runtimeRef = runtime
        ref.opaqueContext = self
    }
    
    var isShuttingDown: Bool {
        exportLock.lock()
        defer { exportLock.unlock() }
        return shuttingDown
    }
    
    func shutdown() {
        exportLock.lock()
        defer { exportLock.unlock() }
        shuttingDown = true
        executionQueue.sync {
            ref.opaqueContext = nil
        
            for value in activeValues {
                value.value.free(self)
            }
    
            globalRef.free(self)
            
            JS_FreeContext(ref)
        }
    }
    
    func newContextClassID() -> Int32 {
        exportLock.lock()
        defer { exportLock.unlock() }
        let new = classCounter
        classCounter += 1
        return new
    }
    
    func newContextFunctionID() -> Int32 {
        exportLock.lock()
        defer { exportLock.unlock() }
        let new = functionCounter
        functionCounter += 1
        return new
    }
    
    func newMethodID() -> Int32 {
        exportLock.lock()
        defer { exportLock.unlock() }
        let new = methodCounter
        methodCounter += 1
        return new
    }
    
    func newPropertyID() -> Int32 {
        exportLock.lock()
        defer { exportLock.unlock() }
        let new = propertyCounter
        propertyCounter += 1
        return new
    }
}

extension JSContext {
    func performThreadSafe(closure: () -> Void) {
        if !isShuttingDown {
            executionQueue.sync {
                closure()
            }
        }
    }
}

extension JSContext {
    func addExport(functionID: Int32, value: @escaping JSFunctionDefinition) {
        exportLock.lock()
        defer { exportLock.unlock() }
        if functions[functionID] != nil { return }
        functions[functionID] = value
    }
    
    func findExport(functionID: Int32) -> JSFunctionDefinition? {
        exportLock.lock()
        defer { exportLock.unlock() }
        return functions[functionID]
    }
    
    func addExport(propertyID: Int32, value: @escaping JSPropertyGetterDefinition) {
        exportLock.lock()
        defer { exportLock.unlock() }
        if propertyGetters[propertyID] != nil { return }
        propertyGetters[propertyID] = value
    }
    
    func findExport(propertyID: Int32) -> JSPropertyGetterDefinition? {
        exportLock.lock()
        defer { exportLock.unlock() }
        return propertyGetters[propertyID]
    }
    
    func addExport(propertyID: Int32, value: @escaping JSPropertySetterDefinition) {
        exportLock.lock()
        defer { exportLock.unlock() }
        if propertySetters[propertyID] != nil { return }
        propertySetters[propertyID] = value
    }
    
    func findExport(propertyID: Int32) -> JSPropertySetterDefinition? {
        exportLock.lock()
        defer { exportLock.unlock() }
        return propertySetters[propertyID]
    }
    func addExport(classID: Int32, value: JSClassInfo) {
        exportLock.lock()
        defer { exportLock.unlock() }
        if classes[classID] != nil { return }
        classes[classID] = value
    }
    
    func findExport(classID: Int32) -> JSClassInfo? {
        exportLock.lock()
        defer { exportLock.unlock() }
        return classes[classID]
    }
    
    func findExport(classType: JSExport.Type) -> JSClassInfo? {
        exportLock.lock()
        defer { exportLock.unlock() }
        // there's enough guards elsewhere to make sure there's only one match.
        let found = classes.filter { key, classInfo in
            return classInfo.type == classType
        }
        return found.first?.value
    }
    
    func addExport(instance: JSClassInstanceInfo) {
        exportLock.lock()
        defer { exportLock.unlock() }
        instances.append(instance)
    }
    
    func addExport(methodID: Int32, name: String) {
        exportLock.lock()
        defer { exportLock.unlock() }
        methodIDs[methodID] = name
    }
    
    func findExport(methodID: Int32) -> String? {
        exportLock.lock()
        defer { exportLock.unlock() }
        return methodIDs[methodID]
    }
    
    func addActiveValue(value: JSRetainedValue) {
        if isShuttingDown {
            value.value.free(self)
            return
        }
        exportLock.lock()
        defer { exportLock.unlock() }
        activeValues.append(value)
    }
    
    func freeActiveValue(value: JSRetainedValue) {
        if isShuttingDown { return }
        
        exportLock.lock()
        defer { exportLock.unlock() }
        let found = activeValues.filter { export in
            return export === value
        }
        if let v = found.first {
            activeValues = activeValues.filter { export in
                return export !== v
            }
            v.value.free(self)
        }
    }
}

