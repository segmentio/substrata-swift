//
//  SubstrataTests.swift
//  
//
//  Created by Brandon Sneed on 5/25/22.
//

import XCTest
@testable import Substrata

class CoreTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        EdgeFunctionJS.reset()
    }

    func testClassExtend() throws {
        let engine = JSEngine()
        engine.exceptionHandler = { error in
            print(error)
        }
        
        engine.export(type: EdgeFunctionJS.self, className: "EdgeFunction")
        engine.evaluate(script: """
        class TestSuper extends EdgeFunction {
            constructor(thing) {
                console.log("js: TestSuper.constructor() called")
                super(thing);
                return this;
            }
            
            update(settings, type) {
                console.log("js: TestSuper.update() called")
                if (type == true) {
                    console.log(settings)
                }
            }
            
            execute(event) {
                console.log("js: TestSuper.execute() called");
                console.log(typeof this)
                return super.execute(event);
            }
        
            myInstanceMethod(arg) {
                console.log("js: TestSuper.myInstanceMethod() called");
                super.myInstanceMethod(arg)
                return 1337
            }
        };
        """)

        engine.evaluate(script: "let a1 = new EdgeFunction(true);")
        XCTAssertFalse(Console.logged.contains("js: TestSuper.constructor() called"))
        let a1: Bool? = engine.evaluate(script: "a1.myInstanceMethod(true);")!.typed()
        XCTAssertTrue(a1 == true)
        
        engine.evaluate(script: "let a2 = new TestSuper(true);")
        XCTAssertTrue(Console.logged.contains("js: TestSuper.constructor() called"))
        let a2: Int? = engine.evaluate(script: "a2.myInstanceMethod(true);")!.typed()
        XCTAssertTrue(a2 == 1337)
        
    }
    
    func testClassCall() throws {
        let engine = JSEngine()
        engine.exceptionHandler = { error in
            print(error)
        }
        
        engine.export(type: EdgeFunctionJS.self, className: "EdgeFunction")

        engine.evaluate(script: "let a = new EdgeFunction(true);")
        let o = engine.value(for: "a")
        XCTAssertTrue(o is EdgeFunctionJS)
    }
    
    /**
     Class / static properties are not supported at this time.  Hopefully in the future.
     */
    /*
    func testClassProps() throws {
        let engine = JSEngine()
        engine.exceptionHandler = { error in
            print(error)
        }

        engine.export(type: EdgeFunctionJS.self, className: "EdgeFunction")
        
        /*let a0 = engine.evaluate(script: "let e = new EdgeFunction(true)")
        print(a0)
        let a1 = engine.evaluate(script: "e.myBool")
        print(a1)*/
        let a = engine.evaluate(script: "EdgeFunction.aStaticBool")
        print(a)
        let b = engine.evaluate(script: "EdgeFunction.myStaticBool = false")
        print(b)
        let c = engine.evaluate(script: "EdgeFunction.myStaticBool = true")
        print(b)
        let v = engine.evaluate(script: "EdgeFunction.aStaticBool")
        print(v)
        XCTAssertTrue(EdgeFunctionJS.myStaticBool!)

        engine.evaluate(script: "let a = new EdgeFunction(true)")
        engine.evaluate(script: "a.myBool = true")
        let value = engine.evaluate(script: "a.myBool")
        XCTAssertFalse(value!.typed()!)
    }
     */
    
    func testInstanceMethods() throws {
        let engine = JSEngine()
        engine.exceptionHandler = { error in
            print(error)
        }
        
        engine.export(type: EdgeFunctionJS.self, className: "EdgeFunction")

        engine.evaluate(script: "let a1 = new EdgeFunction(true);")
        let aObject = engine["a1"]
        XCTAssertTrue(aObject is EdgeFunctionJS)
        let result: Bool? = engine.evaluate(script: "a1.myInstanceMethod(true);")!.typed()
        XCTAssertTrue(result == true)
        
        var myStaticProp = false
        
        engine.evaluate(script: "let testObj = new Object()")
        let testObj = engine["testObj"]?.typed(as: JSObject.self)
        XCTAssertNotNil(testObj)
        
        let myStaticMethod: ([JSConvertible]) -> JSConvertible? = { args in
            myStaticProp = true
            return 123
        }
        
        let m = engine.export(function: myStaticMethod, named: "myStaticMethod")
        testObj?["myNewMethod"] = m
        
        let r = engine.evaluate(script: "testObj.myNewMethod()")?.typed(as: Int.self)
        XCTAssertEqual(r, 123)
        XCTAssertEqual(myStaticProp, true)
    }
    
    func testFnCall() throws {
        /*let context = JSContext()
        context.exceptionHandler = { context, value in
            print(value)
        }
        
        var result: JSPrimitive

        result = context.evaluate(script: "jsFunction = function(param1, param2, param3) { return param3; }")
        let jsFn = result as! JSFunction
        print(jsFn)
        
        result = jsFn.call(params: [1, 2, 3].map { $0.jsValue(context: context) })
        let typed = result.value(Int.self)!
        XCTAssertEqual(typed, 3)
        
        var called: Bool = false

        let nativeFn = JSFunction(context: context) { context, this, params in
            called = true
            return 15.jsValue(context: context)
        }
        print(nativeFn)
        context["nativeFn"] = nativeFn
        result = context.evaluate(script: "nativeFn(1, 2, 3)")
        let fifteen = result.value(Int.self)
        XCTAssertNotNil(result)
        XCTAssertTrue(called)
        XCTAssertEqual(fifteen!, 15)*/
    }
    
    func testValueInterpretationIntoJS() throws {
    }

    func testValueInterpretationFromJS() throws {
        /*let context = JSContext()
        context.exceptionHandler = { context, value in
            print(value)
        }
        
        var result: JSPrimitive
        var primitive: JSPrimitive?
        var typed: JSConvertible?
        
        result = context.evaluate(script: "myBool = true")
        print(result)
        primitive = result.typed(JSBoolean.self)
        typed = result.value(Bool.self)
        XCTAssertNotNil(result)
        XCTAssertTrue(result.isBoolean)
        XCTAssertTrue(primitive is JSBoolean)
        XCTAssertTrue(typed as! Bool)
        
        result = context.evaluate(script: "myDouble = 3.14")
        print(result)
        primitive = result.typed(JSNumber.self)
        typed = result.value(Double.self)
        XCTAssertNotNil(result)
        XCTAssertTrue(result.isNumber)
        XCTAssertTrue(primitive is JSNumber)
        XCTAssertEqual(typed as! Double, 3.14)

        result = context.evaluate(script: "myFloat = 3.1")
        print(result)
        primitive = result.typed(JSNumber.self)
        typed = result.value(Float.self)
        XCTAssertNotNil(result)
        XCTAssertTrue(result.isNumber)
        XCTAssertTrue(primitive is JSNumber)
        XCTAssertEqual(typed as! Float, 3.1)

        result = context.evaluate(script: "myInt = -1337")
        print(result)
        primitive = result.typed(JSNumber.self)
        typed = result.value(Int.self)
        XCTAssertNotNil(result)
        XCTAssertTrue(result.isNumber)
        XCTAssertTrue(primitive is JSNumber)
        XCTAssertEqual(typed as! Int, -1337)

        result = context.evaluate(script: "myUInt = 1337")
        print(result)
        primitive = result.typed(JSNumber.self)
        typed = result.value(UInt.self)
        XCTAssertNotNil(result)
        XCTAssertTrue(result.isNumber)
        XCTAssertTrue(primitive is JSNumber)
        XCTAssertEqual(typed as! UInt, 1337)

        result = context.evaluate(script: "myString = 'howdy doody'")
        print(result)
        primitive = result.typed(JSString.self)
        typed = result.value(String.self)
        XCTAssertNotNil(result)
        XCTAssertTrue(result.isString)
        XCTAssertTrue(primitive is JSString)
        XCTAssertEqual(typed as! String, "howdy doody")
        
        result = context.evaluate(script: "myArray = [1, 'hello', 2, 3.14]")
        print(result)
        primitive = result.typed(JSArray.self)
        let array = result.value([Any].self)!
        XCTAssertNotNil(result)
        XCTAssertTrue(result.isArray)
        XCTAssertTrue(primitive is JSArray)
        XCTAssertEqual(array.count, 4)
        XCTAssertEqual(array[0] as! Double, 1)
        XCTAssertEqual(array[1] as! String, "hello")
        XCTAssertEqual(array[2] as! Double, 2)
        XCTAssertEqual(array[3] as! Double, 3.14)

        result = context.evaluate(script: "myObject = { key: 'value', obj: { a: 1 }, arr: [1, 2, 3] }")
        print(result)
        primitive = result.typed(JSObject.self)
        let object = result.value([String: Any].self)!
        XCTAssertNotNil(result)
        XCTAssertTrue(result.isObject)
        XCTAssertTrue(primitive is JSObject)
        XCTAssertEqual(object.keys.count, 3)
        XCTAssertEqual(object["key"] as! String, "value")
        XCTAssertEqual((object["obj"] as! [String: Any])["a"] as! Double, 1)
        XCTAssertEqual(object["arr"] as! [Double], [1.0, 2.0, 3.0])
        
        result = context.evaluate(script: "myFunction = function(params) { myString = 'blah blah blah'; return 0; }")
        print(result)
        primitive = result.typed(JSFunction.self)
        let function = result.value(JSFunctionInfo.self)
        XCTAssertNotNil(result)
        XCTAssertTrue(result.isFunction)
        XCTAssertTrue(primitive is JSFunction)
        // it's a function defined in JS, so this should be
        // nil since we don't have callback info for it.
        XCTAssertNil(function)*/
    }

}
