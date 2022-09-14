//
//  ConversionTests.swift
//
//
//  Created by Brandon Sneed on 5/2/22.
//

import XCTest
@testable import Substrata

class ConversionTests: XCTestCase {

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

    func testMassConversionOut() throws {
        let engine = JSEngine()
        engine.errorHandler = { error in
            XCTFail()
            print(error)
        }
        
        try! engine.expose(name: "EdgeFunction", classType: EdgeFunctionJS.self)
        
        let bundle = Bundle.module
        let bundleURL = bundle.url(forResource: "ConversionTestData", withExtension: "js")
        engine.loadBundle(url: bundleURL!)
        
        let r = engine.object(key: "conversionSamples")
        XCTAssertNotNil(r)
        
        let samples = r as? [String: JSConvertible]
        XCTAssertNotNil(samples)
        
        // test basic stuff ....
        XCTAssertTrue(samples!["anInt"]!.typed(Int.self) == 1234)
        XCTAssertTrue(samples!["aBool"]!.typed(Bool.self) == true)
        XCTAssertTrue(samples!["anotherBool"]!.typed(Bool.self) == false)
        XCTAssertTrue(samples!["aDouble"]!.typed(Double.self) == 3.14)
        XCTAssertTrue(samples!["aString"]!.typed(String.self) == "booya")
        XCTAssertTrue(samples!["aNull"]!.typed(NSNull.self) != nil)
        XCTAssertTrue((samples!["anArray"]! as! [JSConvertible]).count == 6)
        XCTAssertTrue((samples!["aDictionary"]! as! [String: JSConvertible]).keys.count == 7)
        
        // test nested array stuff ...
        let array = samples!["anArray"]! as! [JSConvertible]
        let subArray = array[4] as! [JSConvertible]
        let subDict = array[5] as! [String: JSConvertible]
        XCTAssertNotNil(array)
        XCTAssertNotNil(subArray)
        XCTAssertNotNil(subDict)
        
        XCTAssertTrue(array[0] is EdgeFunctionJS)
        XCTAssertTrue(subArray[0] as! String == "blah1")
        XCTAssertTrue(subDict["anotherBool"] as! Bool == false)
        
        // test nested dictionary stuff ...
        let dict = samples!["aDictionary"]! as! [String: JSConvertible]
        let nestedArray = dict["anArray"] as! [JSConvertible]
        let nestedDict = dict["aDictionary"] as! [String: JSConvertible]
        XCTAssertNotNil(dict)
        XCTAssertNotNil(nestedArray)
        XCTAssertNotNil(nestedDict)
        
        XCTAssertTrue(dict["aDouble"] as! Double == 3.14)
        XCTAssertTrue(nestedDict["anEdgeFn"]! is EdgeFunctionJS)
        XCTAssertTrue(nestedArray[0] as! String == "test1")
        XCTAssertTrue((nestedDict["anArray"] as! [JSConvertible]).count == 4)
    }

}
