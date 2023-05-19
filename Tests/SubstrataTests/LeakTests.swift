//
//  LeakTests.swift
//  
//
//  Created by Brandon Sneed on 1/10/23.
//

import XCTest
@testable import Substrata

final class LeakTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        EdgeFunctionJS.reset()
    }

    func testLeaksSimple() throws {
        let engine = JSEngine()
        var errorHit = false
        engine.exceptionHandler = { error in
            print(error)
            errorHit = true
        }
        
        let analytics = AnalyticsJS()
        engine.export(instance: analytics, className: "Analytics", variableName: "analytics")
        var r = engine.evaluate(script: "analytics.track()")
        XCTAssertEqual(r!.typed(), 1)
        
        engine.export(type: EdgeFunctionJS.self, className: "MockObject")
        engine.export(function: myFunction, named: "myFunction")
        engine.evaluate(script: "var a = 1+1;")
        r = engine.evaluate(script: "var m = new MockObject(true); m.myBool = true; m.myBool")
        XCTAssertTrue(r!.typed()!)
        r = engine.evaluate(script: "m.myInstanceMethod(true)")
        XCTAssertTrue(r!.typed()!)
        r = engine.evaluate(script: "MockObject.myStaticMethod(true)")
        XCTAssertTrue(r!.typed()!)
        r = engine.evaluate(script: "MockObject.myStaticBool")
        XCTAssertFalse(r!.typed()!)
        r = engine.evaluate(script: "MockObject.myStaticBool = true; MockObject.myStaticBool;")
        XCTAssertTrue(r!.typed()!)
        r = engine.evaluate(script: "myFunction(true)")
        XCTAssertTrue(r!.typed()!)
        r = engine.value(for: "MockObject.myStaticBool")
        XCTAssertTrue(r!.typed()!)
        engine.setValue(for: "blah", value: true)
        r = engine.value(for: "blah")
        XCTAssertTrue(r!.typed()!)
        r = engine.evaluate(script: "blah")
        XCTAssertTrue(r!.typed()!)
        engine.evaluate(script: "var obj = new Object()")
        engine.setValue(for: "obj.booya", value: true)
        r = engine.value(for: "obj.booya")
        XCTAssertTrue(r!.typed()!)
        r = engine.call(functionName: "MockObject.myStaticMethod", args: [true])
        XCTAssertTrue(r!.typed()!)
        
        engine.evaluate(script: "console.log('hello from console.log', true, null, 3.14, 1.00);")
        
        engine.call(functionName: ", : [};", args: [])
        XCTAssertTrue(errorHit)
        
        engine.evaluate(script: "myFunction([1, true, 'hello'])")
        
        engine.evaluate(script: "myFunction({ test: 1, blah: 'booya', jibby: 3.14 })")
        
        engine.bridge?["myBool"] = true
        r = engine.bridge?["myBool"]
        XCTAssertTrue(r!.typed()!)
        r = engine.evaluate(script: "dataBridge.myBool")
        XCTAssertTrue(r!.typed()!)

        RunLoop.main.run(until: Date(timeIntervalSinceNow: 1))

        checkIfLeaked(engine)
    }

}
