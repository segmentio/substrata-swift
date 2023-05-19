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
        /*let context = JSEngine()
        context.exceptionHandler = { context, value in
            print(value)
        }
        
        let edgeFn = try! JSObject(context: context, type: EdgeFunctionJS.self)
        context[EdgeFunctionJS.className] = edgeFn

        //context.evaluate(script: "EdgeFunction.prototype = {}")
        context.evaluate(script: """
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

        context.evaluate(script: "let a = new TestSuper(1, 2, 3);")
        let o = context["a"]
        print(o)*/
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
    
    func testClassProps() throws {
        let engine = JSEngine()
        engine.exceptionHandler = { error in
            print(error)
        }

        engine.export(type: EdgeFunctionJS.self, className: "EdgeFunction")
        
        engine.evaluate(script: "EdgeFunction.myStaticBool = true")
        XCTAssertTrue(EdgeFunctionJS.myStaticBool!)

        engine.evaluate(script: "let a = new EdgeFunction(true)")
        let value = engine.evaluate(script: "a.myBool")
        XCTAssertFalse(value!.typed()!)
    }
    
    func testClassMethods() throws {
        /*let engine = JSEngine()
        engine.exceptionHandler = { error in
            print(error)
        }

        engine.export(type: EdgeFunctionJS.self, className: "EdgeFunction")

        var myStaticProp = false
        
        let edgeFn = try! JSObject(context: context, type: EdgeFunctionJS.self)
        context[EdgeFunctionJS.className] = edgeFn
        edgeFn.addMethod(name: "myStaticMethod") { context, this, params in
            myStaticProp = true
            return params.jsValue(context: context)
        }
        
        let returns = context.evaluate(script: "EdgeFunction.myStaticMethod(1, 2, 3)")
            .value([Int].self)!
        print(returns)
        
        XCTAssertTrue(myStaticProp)
        XCTAssertTrue(returns.count == 3)
        XCTAssertEqual(returns[1], 2)

        context.evaluate(script: "let a = new EdgeFunction(1, 2, 3)")
        
        var isGoodDay = false
        
        let object = context["a"] as! JSObject
        object.addMethod(name: "isGoodDay") { context, this, params in
            guard params.count >= 1 else { return context.undefined }
            guard let value = params[0].value(Bool.self) else { return context.undefined }
            isGoodDay = value
            return params[0]
        }
        
        context.evaluate(script: "a.isGoodDay(true)")

        XCTAssertTrue(isGoodDay)*/
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
