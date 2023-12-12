//
//  File.swift
//  
//
//  Created by Brandon Sneed on 6/6/22.
//

import Foundation
import XCTest

@testable import Substrata

class EngineTests: XCTestCase {
    
    override func tearDownWithError() throws {
        // look for leaks ...
        let leaks = JSLeaks.leaked()
        if leaks.count > 0 {
            XCTFail("Something was leaked in the previous test: \(leaks)")
        }
    }

    func testBundleLoad() throws {
        let engine = JSEngine()
        engine.errorHandler = { error in
            print(error)
        }
        
        var loaded = false
        let bundle = Bundle.module
        let bundleURL = bundle.url(forResource: "BundleTest", withExtension: "js")
        XCTAssertNotNil(bundleURL)
        if let bundleURL = bundleURL {
            engine.loadBundle(url: bundleURL) { error in
                XCTAssertNil(error)
                loaded = true
            }
        }
        
        XCTAssertTrue(loaded)
    }
        
    func testCallUnknownFunction() throws {
        let engine = JSEngine()
        engine.errorHandler = { error in
            print(error)
            
            switch(error) {
            case .evaluationError:
                // the stuff below should've generated an evaluation error
                break
            default:
                XCTFail()
            }
        }

        let r = engine.call(functionName: "blah.booya", params: nil)
        // it's undefined, aka nil
        XCTAssertTrue(r == nil)
    }
    
    func testObjectGetSet() throws {
        let engine = JSEngine()
        engine.errorHandler = { error in
            print(error)
            XCTFail()
        }
        
        engine.setObject(key: "booya", value: 42)
        let value = engine.object(key: "booya")?.typed(Int.self)
        XCTAssertEqual(value!, 42)
        
        let result = engine.evaluate(script: "booya;")?.typed(Int.self)
        XCTAssertNotNil(result)
        XCTAssertEqual(result!, 42)
    }
    
    func testFunctionExposure() throws {
        let engine = JSEngine()
        engine.errorHandler = { error in
            print(error)
            XCTFail()
        }
        
        let quadruple: (JavascriptClass?, JSObject?, JSConvertible?...) -> JSConvertible? = { _, _, params in
            guard let input = params[0]?.typed(Double.self) else { return nil }
            return input * 4
        }
        
        var x: Int = 0
        let returnVoid: (JavascriptClass?, JSObject?, JSConvertible?...) -> JSConvertible? = { _, _, params in
            x = 22
            return nil
        }
        
        engine.expose(name: "quadruple", function: quadruple)
        engine.expose(name: "returnVoid", function: returnVoid)

        let result = engine.call(functionName: "quadruple", params: 3)?.typed(Int.self)
        XCTAssertTrue(result! == 12)
        
        let r = engine.call(functionName: "returnVoid", params: nil)
        // r should be nil
        XCTAssertNil(r)
        // to know it actually ran, we set x to 22.
        XCTAssertTrue(x == 22)
    }

    func testFunctionExtension() throws {
        let engine = JSEngine()
        engine.errorHandler = { error in
            print(error)
            XCTFail()
        }
        
        let quadruple: (JavascriptClass?, JSObject?, JSConvertible?...) -> JSConvertible? = { _, _, params in
            guard let input = params[0]?.typed(Double.self) else { return nil }
            return input * 4
        }
        
        engine.evaluate(script: "var myObject = { }")
        
        do {
            try engine.extend(name: "quadruple", object: "myObject", function: quadruple)
        } catch {
            print(error)
            XCTFail()
        }
        
        let result = engine.evaluate(script: "myObject.quadruple(3)") as? Double
        XCTAssertTrue(result! == 12.0)
    }
    
    func testClassExposure() throws {
        let engine = JSEngine()
        engine.errorHandler = { error in
            print(error)
            XCTFail()
        }
        
        try! engine.expose(name: "EdgeFunction", classType: EdgeFunctionJS.self)
        try! engine.expose(name: "Analytics", classType: AnalyticsJS.self)
        _ = engine.evaluate(script: "var a = new Analytics('1234');")
        
        let r = engine.object(key: "a")
        XCTAssertTrue(r is AnalyticsJS)
        
        let o = engine.object(key: "a")?.typed(JSObject.self)
        XCTAssertNil(o)
        
        let result = engine.evaluate(script: "var annie = new Analytics('9876'); annie.track('booya');")
        XCTAssertNil(result)
        
        let obj = engine.evaluate(script: "annie.testObject();")
        XCTAssertNotNil(obj)
        XCTAssertTrue(obj is EdgeFunctionJS)

        engine.evaluate(script: "Analytics.myStaticProperty = true")
        let myStaticProp = engine.evaluate(script: "Analytics.myStaticProperty") as! Bool
        XCTAssertTrue(myStaticProp)
        
        let anonymousId = engine.evaluate(script: "annie.anonymousId") as? String
        XCTAssertEqual(anonymousId, "0123456789")
    }
    
    func testClassInheritance() throws {
        let engine = JSEngine()
        engine.errorHandler = { error in
            print(error)
            XCTFail()
        }
        
        try! engine.expose(name: "EdgeFunction", classType: EdgeFunctionJS.self)
        engine.evaluate(script: """
        class TestSuper extends EdgeFunction {
            constructor(type, destination) {
                //console.log("js: TestSuper.constructor() called")
                super(type, destination);
            }
            
            update(settings, type) {
                //console.log("js: TestSuper.update() called")
                if (type == true) {
                    //console.log(settings)
                }
            }
            
            execute(event) {
                //console.log("js: TestSuper.execute() called");
                //console.log(typeof this)
                //return super.execute(event);
            }
        };
        """)
        
        engine.evaluate(script: "var a = new TestSuper('123')")
        let r = engine.object(key: "a")
        XCTAssertTrue(r is EdgeFunctionJS)
    }

    func testReentry() throws {
        let engine = JSEngine()
        engine.errorHandler = { error in
            print(error)
            XCTFail()
        }
        
        let r = engine.syncRunEngine {
            let v = engine.object(key: "console")
            return v
        }
        XCTAssertNotNil(r)
    }
    
    func testClassInstanceFailure() throws {
        let engine = JSEngine()
        var errorHappened = false
        engine.errorHandler = { error in
            errorHappened = true
            print(error)
        }
        
        let r = engine.evaluate(script: "var a = new Booya()")
        XCTAssertNil(r)
        XCTAssertTrue(errorHappened)
    }
    
    func testClassInstanceOf() throws {
        let engine = JSEngine()
        engine.errorHandler = { error in
            print(error)
            XCTFail()
        }
        
        try! engine.expose(name: "EdgeFunction", classType: EdgeFunctionJS.self)
        try! engine.expose(name: "Analytics", classType: AnalyticsJS.self)
        _ = engine.evaluate(script: "var a = new Analytics('1234');")

        let c = engine.object(key: "a")
        XCTAssertTrue(c is AnalyticsJS)

        let r = engine.evaluate(script: "a instanceof Analytics")
        XCTAssertTrue(r as! Bool)
        let b = engine.evaluate(script: "a instanceof EdgeFunction")
        XCTAssertFalse(b as! Bool)

        let f = engine.evaluate(script: "delete a")
        XCTAssertFalse(f as! Bool)
    }
    
    func testFunctionAsConstructor() throws {
        let engine = JSEngine()
        var errorHappened = false
        engine.errorHandler = { error in
            errorHappened = true
            print(error)
        }
        
        let makeAnEdgeFn: (JavascriptClass?, JSObject?, JSConvertible?...) -> JSConvertible? = { [weak engine] (_, _, params) in
            return try! EdgeFunctionJS(context: engine!.context, params: nil)
        }
        
        engine.expose(name: "myFunc", function: makeAnEdgeFn)
        
        let r = engine.evaluate(script: "var a = new myFunc()")
        XCTAssertNil(r)
        XCTAssertTrue(errorHappened)
    }
    
    func testFunctionInstanceOf() throws {
        let engine = JSEngine()
        engine.errorHandler = { error in
            print(error)
        }
        
        let makeAnEdgeFn: (JavascriptClass?, JSObject?, JSConvertible?...) -> JSConvertible? = { [weak engine] (_, _, params) in
            return try! EdgeFunctionJS(context: engine!.context, params: nil)
        }
        
        engine.expose(name: "myFunc", function: makeAnEdgeFn)
        
        let r = engine.evaluate(script: "let o = myFunc; o instanceof myFunc")
        XCTAssertTrue(r as! Bool)
        let b = engine.evaluate(script: "let b = function() { }; b instanceof myFunc")
        XCTAssertFalse(b as! Bool)
    }
    
    func testFunctionFinalize() throws {
        let engine = JSEngine()
        engine.errorHandler = { error in
            print(error)
            XCTFail()
        }
        
        let makeAnEdgeFn: (JavascriptClass?, JSObject?, JSConvertible?...) -> JSConvertible? = { [weak engine] (_, _, params) in
            return try! EdgeFunctionJS(context: engine!.context, params: nil)
        }
        
        engine.expose(name: "myFunc", function: makeAnEdgeFn)
        
        let r = engine.evaluate(script: "var o = myFunc; delete o")
        XCTAssertFalse(r as! Bool)
    }
    
    func testConsole() throws {
        let engine = JSEngine()
        engine.errorHandler = { error in
            print(error)
            XCTFail()
        }
        
        let r = engine.evaluate(script: "console.log(1, 2, 3)")
        XCTAssertNil(r)
    }
    
    func testJSClassDetection() throws {
        let engine = JSEngine()
        engine.errorHandler = { error in
            print(error)
            XCTFail()
        }
        
        engine.evaluate(script: """
        class MyTestClass {
            constructor(type, destination) {
                this.type = 1
                this.destination = 'hello'
            }
            
            update(settings, type) {
                
            }
            
            execute(event) {
                
            }
        };
        """)
        
        engine.evaluate(script: "let o = {'test': 1}")
        let o = engine.object(key: "o")
        XCTAssertTrue(o is [String: JSConvertible])
        
        engine.evaluate(script: "let n = new MyTestClass()")
        let n = engine.object(key: "n")
        XCTAssertTrue(n is JavascriptValue)
    }
}
