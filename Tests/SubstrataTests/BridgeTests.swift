//
//  BridgeTests.swift
//  
//
//  Created by Brandon Sneed on 1/18/23.
//

import XCTest
@testable import Substrata

final class BridgeTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        EdgeFunctionJS.reset()
    }
    
    func testStressBridge() throws {
        for _ in 0..<1000 {
            try autoreleasepool {
                try testBridge()
            }
        }
    }

    func testBridge() throws {
        let engine = JSEngine()
        engine.exceptionHandler = { error in
            XCTFail()
            print(error)
        }
        
        engine.export(type: EdgeFunctionJS.self, className: "EdgeFunction")
        
        let funkyFunc = engine.export(name: "myFunkyFunc") { args in
            print("myFunkyFuncCalled")
            return nil
        }
        
        engine.bridge["myFunkyFunc"] = funkyFunc
        
        let f = engine.bridge["myFunkyFunc"]
        engine.bridge["myFunkyFunc"] = f

        let edgeFn = engine.evaluate(script: "var edgeFn = new EdgeFunction(true); edgeFn;") as! JSClass
        engine.bridge["myEdgeFn"] = edgeFn
        engine.bridge["myArray"] = [1, 2, "hello"]
        engine.bridge["myDict"] = ["test": 1, "blah": 3.14, "nums": ["1", "2", "3"], "fnClass": edgeFn]
        
        engine.evaluate(script: "console.log(dataBridge.myDict);")
        
        let myEdgeFn = engine.bridge["myEdgeFn"]
        let myArray = engine.bridge["myArray"] as! [JSConvertible]
        let myDict = engine.bridge["myDict"]?.typed(as: Dictionary.self)
        
        XCTAssertTrue(myEdgeFn is JSClass)
        XCTAssertTrue(myArray.count == 3)
        XCTAssertTrue(myArray[2] as! String == "hello")
        XCTAssertTrue(myDict!["blah"] as! Double == 3.14)
        XCTAssertTrue((myDict!["nums"] as! [JSConvertible]).count == 3)
        XCTAssertTrue(myDict!["fnClass"] is JSClass)
        
        engine.evaluate(script: """
            dataBridge["anInt"] = 1234;
            dataBridge["aBool"] = true;
            dataBridge["aDouble"] = 3.14;
            dataBridge["aString"] = "booya";
            dataBridge["aNull"] = null;
        """)
        
        print(engine.evaluate(script: "dataBridge") as Any)
        
        let anInt: Int? = engine.bridge["anInt"]?.typed()
        let aBool: Bool? = engine.bridge["aBool"]?.typed()
        let aDouble: Double? = engine.bridge["aDouble"]?.typed()
        let aString: String? = engine.bridge["aString"]?.typed()
        let aNull: NSNull? = engine.bridge["aNull"]?.typed()
        
        XCTAssertTrue(anInt == 1234)
        XCTAssertTrue(aBool == true)
        XCTAssertTrue(aDouble == 3.14)
        XCTAssertTrue(aString == "booya")
        XCTAssertTrue(aNull != nil)
        
        // set a key to nil and see what happens
        engine.bridge["anInt"] = nil
        let intGone = engine.bridge["anInt"]
        XCTAssertNil(intGone)
    }


}
