//
//  JSEngine.swift
//
//
//  Created by Brandon Sneed on 4/11/22.
//

import Foundation

#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

/**
 JSEngine encapsulates JavascriptCore usage and simplifies it.
 
 Values are converted automatically to the appropriate types
 as needed.  Calls into JavascriptCore are all synchronized on
 the same serial dispatch queue.
 
 ```
     // get the engine instance
     let engine = JSEngine.shared
 
     // set the error handler we want to use
     engine.errorHandler = { error in
        print("javascript error: \(error)")
     }
 
     // execute some js
     let result = engine.execute(script: "1 + 2;") as? Int
     if result == 3 {
        // success!
     }
 ```
 
 */
public class JSEngine: JavascriptEngine {
    /**
     JSEngine singleton.  Due to the performance cost of creating javascript
     contexts in JavascriptCore, we'll use a singleton primarily; though it is
     possible to create an instance of your own as well.
     */
    //public static var shared: JSEngine = JSEngine()
    public let context: JSContext = JSContext()
    
    private var jsErrorHandler: JavascriptErrorHandler? = nil
    private let jsQueue = RecursiveLock()
    
    /**
     Access the data bridge
     
     ```
     engine.bridge?["myKey"] = myValue
     let color = engine.bridge?["color"] as? String
     ```
     */
    public var bridge: JavascriptDataBridge? = nil
    
    /**
     Error handler that will be used if Javascript generates an exception.
     */
    public var errorHandler: JavascriptErrorHandler? {
        get {
            return jsErrorHandler
        }
        set(value) {
            jsErrorHandler = value
        }
    }
    
    public init() {
        setupConsolePassThrough()
        setupExceptionHandler()
        setupDataBridge()
        
        #if DEBUG
        if isUnitTesting {
            JSLeaks.objects.append(self)
        }
        #endif
    }
    
    /**
     Loads a bundle from disk.  Only accepts file URLs.  Any downloading of javascript
     bundles must be done upstream by the caller.  A completion block will be executed
     when done (if specified).
     
     - Parameters:
        - url: file URL of the bundle to load/interpret.
        - completion: Optional completion block when done.
     
     ```
     engine.loadBundle(url: myBundleURL) { error in
        if error {
            print("oh noes, we failed: \(error))
            return
        } else {
            success = true
        }
     }
     ```
     */
    public func loadBundle(url: URL, completion: BundleLoaded? = nil) {
        var jsError: JavascriptEngineError? = nil
        
        if url.isFileURL == false || FileManager.default.fileExists(atPath: url.path) == false {
            jsError = JavascriptEngineError.bundleNotFound
            completion?(jsError)
            return
        }

        var jsSource: String? = nil
        do {
            jsSource = try String(contentsOf: url)
            if jsSource == nil {
                jsError = JavascriptEngineError.unableToLoad
            }
        } catch {
            jsError = JavascriptEngineError.unknownError(error)
        }
            
        if let jsSource = jsSource {
            _ = jsQueue.perform { [weak self] in
                self?.context.evaluate(script: jsSource)
            }
        }
        
        completion?(jsError)
    }
    
    /**
     Get the value of any key on the global object.
     
     - Parameters:
        - key: The key to look for on the global object.
     
     - Returns: A convertible value (int, string, array, etc...)
     
     ```
     let numnums = engine.object(key: "numberArray") as? [Int]
     ```
     */
    public func object(key: String) -> JSConvertible? {
        var result: JSConvertible? = nil
        
        jsQueue.perform { [weak self] in
            guard let self = self else { return }
            result = self.context[key].value
        }
        
        return result
    }
    
    /**
     Get a value to the given key of the global object in JS.
     
     - Paramters:
        - key: the key to set.
        - value: the value to give said key.
     
     ```
     engine.setObject(key: "numberArray", value: [1, 2, 3])
     ```
     */
    public func setObject(key: String, value: JSConvertible) {
        jsQueue.perform { [weak self] in
            guard let self = self else { return }
            let v = value.jsValue(context: self.context)
            self.context[key] = v
        }
    }
    
    /**
     Exposes a native class to Javascript by name.
     
     Classes that will be exposed need to have a protocol marked with JSExports
     to allow any methods or properties to be accessible.
     
     If you intend on allowing the class to be used as a return value or parameters
     it may also be useful to conform to JSConvertible.
     
     - Parameters:
        - classType: The class type being exposed.
        - name: The name that will be used on the JS side.
     
     ```
     protocol MyClassExports: JSExport {
        var myValue: Int
        func doSomething() -> Bool
     }
     
     @objc
     class MyClass: NSObject, MyClassExports, JSConvertible {
        var myValue: Int = 5
        func doSomething() -> Bool { return true }
     }
     
     engine.expose(classType: MyClass.type, name: "MyClass")
     
     let something = engine.execute(script: "var c = new MyClass(); c.doSomething();") as? Bool
     if something {
        // success!
     }
     
     let jsClassInstance = engine.execute(script: "c;") as? MyClass
     if jsClassInstance {
        jsClassInstance.doSomething()
     }
     ```
     */
    public func expose(name: String, classType: JavascriptClass.Type) throws {
        try jsQueue.perform { [weak self] in
            guard let self = self else { return }
            let obj = try JSObject(context: self.context, type: classType)
            self.context[name] = obj
        }
    }
    
    /**
     Exposes a native function to Javascript by name.
     
     - Parameters:
        - function: The function to expose to JS.
        - name: The name that will be used on the JS side.
     
     ```
     let quadruple: @convention(block) (Int) -> Int = { input in
         return input * 4
     }
     
     engine.expose(function: quadruple, name: "quadruple")
     let result = engine.execute(script: "quadruple(3);") as? Int
     if result == 12 {
        // success!
     }
     ```
     */
    public func expose(name: String, function: @escaping JavascriptFunction) {
        jsQueue.perform { [weak self] in
            guard let self = self else { return }
            let fn = JSFunction(context: self.context) { [weak self] (context, this, params) in
                let convertedParams = params.map { $0.value }
                let result = function(nil, this, convertedParams)
                return result?.jsValue(context: self!.context) ?? self!.context.undefined
            }
            self.context[name] = fn
        }
    }
    
    /**
     Extend an existing Javascript object.
     
     - Parameters:
        - object: The name of the object that will be extended.
        - function: The function to be added to the object.
        - name: The name of the function on the JS side.
     
     ```
     let doSomething: @convention(block) () -> Void = {
         print("hello")
     }
     
     engine.extend(object: "console", function: doSomething, name: "doSomething")
     ```
     */
    public func extend(name: String, object: String, function: @escaping JavascriptFunction) throws {
        try jsQueue.perform { [weak self] in
            guard let self = self else { return }
            if let target = context[object] as? JSObject {
                let fn = JSFunction(context: self.context) { context, this, params in
                    let convertedParams = params.map { $0.value }
                    let result = function(nil, this, convertedParams)
                    return result?.jsValue(context: context) ?? context.undefined
                }
                target[name] = fn
            } else {
                throw JavascriptEngineError.extensionFailed
            }
        }
    }
    
    /**
     Call a Javascript function directly by name.  Javascript handles the name resolution.
     
     - Parameters:
        - functionName: the name of the function to call.
        - params: The parameters to be given or nil.
     
     - Returns: The resuling value of the function call if not void.
     
     ```
     let result = engine.call(functionName: "thing.addNumbers", params: [1, 2, 3]) as? Int
     if result == 6 {
        // success!
     }
     ```
     */
    @discardableResult
    public func call(functionName: String, params: JSConvertible?...) -> JSConvertible? {
        var result: JSConvertible? = nil
        jsQueue.perform { [weak self] in
            guard let self = self else { return }
            // let JS do the name resolution for us
            if let f = self.context.evaluate(script: functionName).typed(JSFunction.self) {
                var jsParams = [JSPrimitive]()
                for p in params {
                    if let v = p?.jsValue(context: self.context) {
                        jsParams.append(v)
                    }
                }
                result = f.call(this: nil, params: jsParams).value
            }
        }
        return result
    }

    /**
     Executes a given script.
     
     - Parameters:
        - script: The script to execute.
     
     - Returns: Any result that was given back, or nil.
     */
    @discardableResult
    public func evaluate(script: String) -> JSConvertible? {
        var result: JSPrimitive? = nil
        jsQueue.perform { [weak self] in
            guard let self = self else { return }
            result = self.context.evaluate(script: script);
        }
        return result?.value
    }
}

extension JSEngine {
    private func setupConsolePassThrough() {
        //try? expose(name: "console", classType: ConsoleJS.self)
        try? extend(name: "log", object: "console", function: { weakSelf, this, params in
            var msg: String = "js console:"
            params.forEach { param in
                if let p = param {
                    msg += " \(p)"
                }
            }
            print(msg)
            return nil
        })
    }
    
    private func setupExceptionHandler() {
        jsQueue.perform { [weak self] in
            guard let self = self else { return }
            // setup javascript exception handling
            self.context.exceptionHandler = { [weak self] (context, value) in
                if let handler = self?.jsErrorHandler, let error = value.typed(JSError.self) {
                    handler(JavascriptEngineError.evaluationError(error))
                }
            }
        }
    }
    
    private func setupDataBridge() {
        bridge = JSDataBridge(engine: self)
        jsQueue.perform { [weak self] in
            // setup data bridge
            guard let self = self else { return }
            self.context.evaluate(script: "var \(JSDataBridge.dataBridgeKey) = {};")
        }
    }
}

extension JSEngine {
    @discardableResult
    public func syncRunEngine(closure: () -> JSConvertible?) -> JSConvertible? {
        var result: JSConvertible? = nil
        jsQueue.perform {
            result = closure()
        }
        return result
    }
}
