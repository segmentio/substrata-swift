// The Swift Programming Language
// https://docs.swift.org/swift-book

import Foundation
import SubstrataQuickJS

public class JSEngine {
    internal let runtime: JSRuntimeRef
    internal let context: JSContext
    
    public var exceptionHandler: ((JSError) -> Void)? {
        get { return context.exceptionHandler }
        set(value) { context.exceptionHandler = value }
    }
    
    public typealias BundleLoaded = (Bool) -> Void
    public var bridge: JSDataBridge
    
    public init() {
        self.runtime = JS_NewRuntime()
        self.context = JSContext(runtime: runtime)
        self.bridge = JSDataBridge()
        
        JS_SetMaxStackSize(runtime, 1024 * 1024)
        JS_SetMemoryLimit(runtime, 1024 * 1024 * 1024)
        
        setupDefaultObjects()
    }
    
    deinit {
        context.shutdown()
        JS_FreeRuntime(runtime)
    }
    
    public func shutdown() {
        context.shutdown()
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
            evaluate(script: jsSource, evaluator: "JSEngine.loadBundle")
        }
        
        completion?(jsError)
    }
    
    @discardableResult
    public func evaluate(script: String) -> JSConvertible? {
        return evaluate(script: script, evaluator: Constants.Evaluator)
    }

    /// Evaluates a script and returns a result.
    ///
    /// params:
    ///     - script: The script to evaluate
    ///     - evaluator: An optional identifying name of the evaluator, useful in debugging.
    @discardableResult
    public func evaluate(script: String, evaluator: String) -> JSConvertible? {
        var outerResult: JSConvertible? = nil
        context.performThreadSafe { [weak self] in
            guard let self else { return }
            let result = JS_Eval(context.ref, script, script.lengthOfBytes(using: .utf8), evaluator, 0)
            outerResult = result.toJSConvertible(context: context)
            result.free(context)
        }
        return outerResult
    }
    
    public subscript(keyPath: String) -> JSConvertible? {
        get {
            return value(for: keyPath)
        }
        
        set(value) {
            setValue(value, for: keyPath)
        }
    }
    
    public func value(for keyPath: String) -> JSConvertible? {
        guard keyPath.count > 0 else { return nil }
        let result = evaluate(script: keyPath, evaluator: "JSEngine.value")
        return result
    }
    
    @discardableResult
    public func setValue(_ value: JSConvertible?, for keyPath: String) -> Bool {
        var result: Bool = false
    
        guard keyPath.count > 0 else { return result }
        context.performThreadSafe {
            let value = (value as? JSInternalConvertible)?.toJSValue(context: context) ?? JSValue.undefined
            
            var components = keyPath.components(separatedBy: ".")
            guard let last = components.last else { return }
            components.removeLast()
            let path = components.joined(separator: ".")
            
            var pathValue: JSValue
            if path.count == 0 {
                // they're referencing the global object...
                // we don't need to exception check this.
                pathValue = context.globalRef
                result = 0 < JS_SetPropertyStr(context.ref, pathValue, last, value)
            } else {
                // we've got an actual dot-path here...
                pathValue = JS_Eval(context.ref, path, path.lengthOfBytes(using: .utf8), Constants.Evaluator, 0)
                pathValue.handlePossibleException(context: context)
                result = 0 < JS_SetPropertyStr(context.ref, pathValue, last, value)
                pathValue.free(context)
            }
        }
        
        return result
    }
    
    @discardableResult
    public func export(name: String, function: @escaping JSFunctionDefinition) -> JSFunction? {
        if isExported(name: name) {
            #if DEBUG
            fatalError("Substrata Error: Something named `\(name)` already exists!")
            #else
            return nil // if not in debug, just leave.
            #endif
        }
        
        var result: JSFunction? = nil
        
        context.performThreadSafe { [weak self] in
            guard let self else { return }
            let functionID = context.newContextFunctionID()
            
            let newFunction = JS_NewCFunctionMagic(context.ref, { context, this, argc, argv, magic in
                return typedCall(context: context, magic: magic, argc: argc, argv: argv)
            }, name, 1, JS_CFUNC_generic_magic, functionID)
            
            JS_SetPropertyStr(context.ref, context.globalRef, name, newFunction)
            result = JSFunction(value: newFunction, context: context)
            newFunction.free(context)
            
            context.addExport(functionID: functionID, value: function)
        }
        return result
    }
    
    @discardableResult
    public func export(instance: JSExport, className: String, as variableName: String) -> JSClass? {
        if !isExported(name: className) {
            export(type: type(of: instance.self), className: className)
        }
        
        var result: JSClass? = nil
        
        context.performThreadSafe {
            guard let classInfo = context.findExport(classType: type(of: instance)) else { return }
            classInfo.waitingToAttach = instance
            
            let code = "let \(variableName) = new \(className)(); \(variableName);"
            let r = JS_Eval(context.ref, code, code.lengthOfBytes(using: .utf8), Constants.Evaluator, 0)
            r.handlePossibleException(context: context)
            result = JSClass(value: r, context: context)
            r.free(context)
            
            classInfo.waitingToAttach = nil
        }
        
        return result
    }
    
    public func export(type: JSExport.Type, className: String) {
        if isExported(name: className) {
            #if DEBUG
            fatalError("Substrata Error: Something named `\(className)` already exists!")
            #else
            return // if not in debug, just leave.
            #endif
        }

        context.performThreadSafe { [weak self] in
            guard let self else { return }
            
            // set up class in quickJS
            // *************************************
            let cclass = strdup(className)
            let cdd = JSClassDef(class_name: cclass, finalizer: nil, gc_mark: nil, call: nil, exotic: nil)
            let ptr = UnsafeMutablePointer<JSClassDef>.allocate(capacity: 1)
            ptr.initialize(to: cdd)
            var classID: JSClassID = 0
            JS_NewClassID(runtime, &classID)
            JS_NewClass(runtime, classID, ptr)
            free(cclass)
            
            let contextClassID = context.newContextClassID()
            
            // give it to the export list
            let classInfo = JSClassInfo(type: type, classID: classID, name: className)
            context.addExport(classID: contextClassID, value: classInfo)
            
            // set up instance proto for class
            // *************************************
            let instanceProto = JS_NewObject(context.ref)
            
            let constructor = JS_NewCFunctionMagic(context.ref, { context, this, argc, argv, magic in
                return typedConstruct(context: context, this: this, magic: magic, argc: argc, argv: argv)
            }, className, 1, JS_CFUNC_constructor_magic, contextClassID)
            
            // set the static proto on the constructor.
            JS_DefinePropertyValueStr(context.ref, context.globalRef, className,
                                      constructor,
                                      JS_PROP_WRITABLE | JS_PROP_CONFIGURABLE);
            JS_SetConstructor(context.ref, constructor, instanceProto)
            
            // make a dummy instance to get the method names.
            let dummy = type.init()
            let dummyInstanceExports = dummy.exportedMethods
            
            for export in dummyInstanceExports {
                let methodID = context.newMethodID()
                let methodName = export.key
                
                let method = JS_NewCFunctionMagic(context.ref, { context, this, argc, argv, magic in
                    return typedInstanceMethod(context: context, this: this, argc: argc, argv: argv, magic: magic)
                }, methodName, 1, JS_CFUNC_generic_magic, methodID)
                
                // set this as a method on the constructor instance
                JS_SetPropertyStr(context.ref, instanceProto, export.key, method)
                context.addExport(methodID: methodID, name: methodName)
            }
            
            // instance methods get set on the class prototype.
            JS_SetClassProto(context.ref, classID, instanceProto)
            
            // NOTE: Notice we're skipping instance properties ...
            // Those will be applied in typedConstructor on a per-instance basis.
            
            // set up statics for class
            // *************************************
            // statics get set up on the *constructor* itself.
            // do any static init we need to do...
            if let s = type as? JSStatic.Type {
                s.staticInit()
            }
            
            // methods
            let staticMethods = type.exportedMethods
            for export in staticMethods {
                let functionID = context.newContextFunctionID()
                
                let method = JS_NewCFunctionMagic(context.ref, { context, this, argc, argv, magic in
                    return typedCall(context: context, magic: magic, argc: argc, argv: argv)
                }, export.key, 1, JS_CFUNC_generic_magic, functionID)
                
                context.addExport(functionID: functionID, value: export.value)
                JS_SetPropertyStr(context.ref, constructor, export.key, method)
            }
            
            // properties
            let staticProperties = type.exportedProperties
            for export in staticProperties {
                // get'ers gonna get.
                var propFlags = JS_PROP_HAS_WRITABLE | JS_PROP_HAS_ENUMERABLE | JS_PROP_HAS_GET
                let getterID = context.newPropertyID()
                let getter = JS_NewCFunctionMagic(context.ref, { context, this, argc, argv, magic in
                    return typedGetter(context: context, magic: magic)
                }, export.key, 1, JS_CFUNC_generic_magic, getterID)
                context.addExport(propertyID: getterID, value: export.value.getter)
                
                var setter = JSValue.undefined
                // if we have a setter for this homeboy, set it up.
                if let exportSetter = export.value.setter {
                    propFlags |= JS_PROP_HAS_SET
                    
                    let setterID = context.newPropertyID()
                
                    setter = JS_NewCFunctionMagic(context.ref, { context, this, argc, argv, magic in
                        let arg = argv?[0] ?? JSValue.null
                        return typedSetter(context: context, magic: magic, arg: arg)
                    }, export.key, 1, JS_CFUNC_generic_magic, setterID)
                    
                    context.addExport(propertyID: setterID, value: exportSetter)
                }
                
                let propAtom = JS_NewAtom(context.ref, export.key)
                JS_DefineProperty(context.ref, constructor, propAtom, JSValue.undefined, getter, setter, Int32(propFlags))
                JS_FreeAtom(context.ref, propAtom)
                
                // avoid leakage.
                getter.free(context)
                setter.free(context)
            }
        }
    }
    
    public func perform(closure: () -> Void) {
        context.performThreadSafe {
            closure()
        }
    }
}

extension JSEngine {
    internal func setupDefaultObjects() {
        // setup the bridge
        bridge.setEngine(self)
        // setup our builtin functions
        context.builtIns = Builtins(engine: self)
        // export console
        export(type: ConsoleJS.self, className: "console")
    }
    
    internal func isExported(name: String) -> Bool {
        var result: Bool = false
        context.performThreadSafe { [weak self] in
            guard let self else { return }
            result = context.globalRef.hasProperty(context: context, string: name)
        }
        return result
    }
}
