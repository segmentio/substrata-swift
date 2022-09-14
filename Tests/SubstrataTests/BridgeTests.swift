//
//  BridgeTests.swift
//
//
//  Created by Brandon Sneed on 5/2/22.
//

import XCTest
@testable import Substrata

class BridgeTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // look for leaks ...
        let leaks = JSLeaks.leaked()
        if leaks.count > 0 {
            XCTFail("Something was leaked in the previous test: \(leaks)")
        }
    }

    func testBridge() throws {
        let engine = JSEngine()
        engine.errorHandler = { error in
            XCTFail()
            print(error)
        }
        
        try! engine.expose(name: "EdgeFunction", classType: EdgeFunctionJS.self)

        engine.bridge?["myEdgeFn"] = try! EdgeFunctionJS(context: engine.context, params: nil)
        engine.bridge?["myArray"] = [1, 2, "hello"]
        engine.bridge?["myDict"] = ["test": 1, "blah": 3.14, "nums": ["1", "2", "3"], "fn": try! EdgeFunctionJS(context: engine.context, params: nil)]
        
        let myEdgeFn = engine.bridge?["myEdgeFn"]
        let myArray = engine.bridge?["myArray"] as! [JSConvertible]
        let myDict = engine.bridge?["myDict"] as! [String: JSConvertible]
        
        XCTAssertTrue(myEdgeFn is EdgeFunctionJS)
        XCTAssertTrue(myArray.count == 3)
        XCTAssertTrue(myArray[2] as! String == "hello")
        XCTAssertTrue(myDict["blah"] as! Double == 3.14)
        XCTAssertTrue((myDict["nums"] as! [JSConvertible]).count == 3)
        XCTAssertTrue(myDict["fn"] is EdgeFunctionJS)
        
        engine.evaluate(script: """
            dataBridge["anInt"] = 1234;
            dataBridge["aBool"] = true;
            dataBridge["aDouble"] = 3.14;
            dataBridge["aString"] = "booya";
            dataBridge["aNull"] = null;
        """)
        
        let anInt = engine.bridge?["anInt"]!.typed(Int.self)
        let aBool = engine.bridge?["aBool"]!.typed(Bool.self)
        let aDouble = engine.bridge?["aDouble"]!.typed(Double.self)
        let aString = engine.bridge?["aString"]!.typed(String.self)
        let aNull = engine.bridge?["aNull"]!.typed(NSNull.self)
        
        XCTAssertTrue(anInt == 1234)
        XCTAssertTrue(aBool == true)
        XCTAssertTrue(aDouble == 3.14)
        XCTAssertTrue(aString == "booya")
        XCTAssertTrue(aNull != nil)
        
        // set a key to nil and see what happens
        engine.bridge?["anInt"] = nil
        let intGone = engine.bridge?["anInt"]
        XCTAssertNil(intGone)
    }

}
