//
//  TypeTests.swift
//  
//
//  Created by Brandon Sneed on 1/17/24.
//

import XCTest
@testable import Substrata
@testable import SubstrataQuickJS

final class TypeTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testError() throws {
        let engine = JSEngine()
        var exceptionHit = false
        engine.exceptionHandler = { error in
            exceptionHit = true
        }
        let result = engine.evaluate(script: """
        let e = new Error("hello from errorland.");
        e;
        """)

        XCTAssertTrue(result is JSError)
        XCTAssertFalse(exceptionHit)
    }

    func testException() throws {
        let engine = JSEngine()
        var exceptionHit = false
        engine.exceptionHandler = { error in
            exceptionHit = true
            print(error)
        }
        // TODO: Fix the nested error output (cuz `cause` can be an Error object) this generates.
        engine.evaluate(script: """
        try {
            doFailSomeWay();
        } catch (err) {
            throw new Error("Failed in some way", { cause: err });
        }
        """)
        
        XCTAssertTrue(exceptionHit)
    }

    func testUndefined() throws {
        let engine = JSEngine()
        let r = engine.evaluate(script: "undefined")
        XCTAssertNil(r)
    }
    
    func testNull() throws {
        let engine = JSEngine()
        let r = engine.evaluate(script: "null")?.typed(as: NSNull.self)
        XCTAssertEqual(r, NSNull())
        let out = r!.toJSValue(context: engine.context)!
        XCTAssertTrue(JS_IsNull(out) > 0)
        out.free(engine.context)
    }
    
    func testString() throws {
        let engine = JSEngine()
        let r = engine.evaluate(script: "'myString'")?.typed(as: String.self)
        XCTAssertEqual(r, "myString")
        let out = r!.toJSValue(context: engine.context)!
        XCTAssertTrue(JS_IsString(out) > 0)
        out.free(engine.context)
    }

    func testBool() throws {
        let engine = JSEngine()
        let r = engine.evaluate(script: "true")?.typed(as: Bool.self)
        XCTAssertEqual(r, true)
        let out = r!.toJSValue(context: engine.context)!
        XCTAssertTrue(JS_IsBool(out) > 0)
        out.free(engine.context)
    }
    
    func testJSError() throws {
        let engine = JSEngine()
        let r = engine.evaluate(script: "Error('test')")?.typed(as: JSError.self)!
        XCTAssertNotNil(r)
        let out = r!.toJSValue(context: engine.context)
        // we won't make an error on the native side.
        XCTAssertNil(out)
    }

    func testInt() throws {
        let engine = JSEngine()
        let r = engine.evaluate(script: "-53")?.typed(as: Int.self)
        XCTAssertEqual(r, -53)
        let out = r!.toJSValue(context: engine.context)!
        XCTAssertTrue(JS_IsNumber(out) > 0)
        out.free(engine.context)
    }

    func testUInt() throws {
        let engine = JSEngine()
        let r = engine.evaluate(script: "53")?.typed(as: UInt.self)
        XCTAssertEqual(r, 53)
        let out = r!.toJSValue(context: engine.context)!
        XCTAssertTrue(JS_IsNumber(out) > 0)
        out.free(engine.context)
    }

    func testDouble() throws {
        let engine = JSEngine()
        let r = engine.evaluate(script: "53.1")?.typed(as: Double.self)
        XCTAssertEqual(r, 53.1)
        let out = r!.toJSValue(context: engine.context)!
        XCTAssertTrue(JS_IsNumber(out) > 0)
        out.free(engine.context)
    }

    func testFloat() throws {
        let engine = JSEngine()
        let r = engine.evaluate(script: "53.1")?.typed(as: Float.self)
        XCTAssertEqual(r, 53.1)
        let out = r!.toJSValue(context: engine.context)!
        XCTAssertTrue(JS_IsNumber(out) > 0)
        out.free(engine.context)
    }
    
    func testArray() throws {
        let engine = JSEngine()
        let r = engine.evaluate(script: "[1, 2, 3]")?.typed(as: Array.self)
        XCTAssertEqual(r!.count, 3)
        let out = r!.toJSValue(context: engine.context)!
        XCTAssertTrue(JS_IsArray(engine.context.ref, out) > 0)
        out.free(engine.context)
    }

    func testDictionary() throws {
        let engine = JSEngine()
        let r = engine.evaluate(script: "const obj = {a: 1, b: 2, c: 3}; obj;")?.typed(as: Dictionary.self)
        XCTAssertEqual(r!.count, 3)
        let out = r!.toJSValue(context: engine.context)!
        XCTAssertTrue(JS_IsObject(out) > 0)
        let v = out.toJSConvertible(context: engine.context)!.typed(as: Dictionary.self)!
        XCTAssertTrue(v["a"]!.typed(as: Int.self) == 1)
        XCTAssertTrue(v["b"]!.typed(as: Int.self) == 2)
        XCTAssertTrue(v["c"]!.typed(as: Int.self) == 3)
        out.free(engine.context)
    }
    
    func testFunction() throws {
        let engine = JSEngine()
        let r = engine.evaluate(script: """
        function myFunc(param1, param2) {
            console.log("params =", param1, param2)
            return 23
        }

        myFunc;
        """)?.typed(as: JSFunction.self)

        XCTAssertNotNil(r)
        
        if let r {
            print(r)
        }
        
        let fResult = r?.call(args: ["test", 2])?.typed(as: Int.self)
        XCTAssertEqual(fResult, 23)
        XCTAssertEqual(ConsoleJS.wasLogged("params = test 2"), true)
    }
    
    func testClass() throws {
        let engine = JSEngine()
        let r = engine.evaluate(script: """
        class Blah {
            constructor() {
                console.log("blah")
            }
        
            myFunc(param1, param2) {
                console.log("params =", param1, param2)
                return 23
            }
        }
        
        let b = new Blah();
        b;
        """)?.typed(as: JSClass.self)
        XCTAssertTrue(ConsoleJS.wasLogged("blah"))
        XCTAssertNotNil(r)
        
        let myFuncResult = r?.call(method: "myFunc", args: [1, "hello"])?.typed(as: Int.self)
        XCTAssertEqual(myFuncResult, 23)
        XCTAssertTrue(ConsoleJS.wasLogged("params = 1 hello"))
    }
}
