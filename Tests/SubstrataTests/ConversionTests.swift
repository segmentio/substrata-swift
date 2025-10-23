//
//  ConversionTests.swift
//  
//
//  Created by Brandon Sneed on 1/23/23.
//

import XCTest
@testable import Substrata

final class ConversionTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        EdgeFunctionJS.reset()
    }
    
    func testNativeThrowingConstructor() throws {
        let engine = JSEngine()
        var exceptionHit = false
        engine.exceptionHandler = { error in
            exceptionHit = true
            print(error.jsDescription())
        }
        
        engine.export(type: ThrowingConstructorJS.self, className:"ThrowingConstructor")
        
        // test constructor
        let r = engine.evaluate(script: "let x = new ThrowingConstructor(true);")
        XCTAssertNotNil(r)
        XCTAssertTrue(exceptionHit)
    }
    
    func testNativeThrowingOtherStuff() throws {
        let engine = JSEngine()
        var exceptionHit = false
        engine.exceptionHandler = { error in
            exceptionHit = true
            print(error.jsDescription())
        }
        
        engine.export(type: ThrowingConstructorJS.self, className: "ThrowingConstructor")
        
        // test function
        exceptionHit = false
        var r = engine.evaluate(script: "let y = new ThrowingConstructor(false);")
        XCTAssertNil(r)
        let b = engine.evaluate(script: "y.noThrowFunc()")?.typed(as: Int.self)
        XCTAssertEqual(b, 3)
        r = engine.evaluate(script: "y.throwFunc()")
        XCTAssertNotNil(r)
        XCTAssertTrue(exceptionHit)
        
        // test getter
        exceptionHit = false
        r = engine.evaluate(script: "y.throwProp")
        XCTAssertNotNil(r)
        XCTAssertTrue(exceptionHit)
        
        // test setter
        exceptionHit = false
        r = engine.evaluate(script: "y.throwProp = 5")
        XCTAssertNotNil(r)
        XCTAssertTrue(exceptionHit)
    }

    func testMassConversionOut() throws {
        let engine = JSEngine()
        engine.exceptionHandler = { error in
            XCTFail()
            print(error)
        }
        
        engine.export(type: EdgeFunctionJS.self, className:"EdgeFunction")
        
        let bundle = Bundle.module
        let bundleURL = bundle.url(forResource: "ConversionTestData", withExtension: "js")
        engine.loadBundle(url: bundleURL!)
        
        let r = engine.value(for: "conversionSamples")
        XCTAssertNotNil(r)
        
        let samples = r?.typed(as: Dictionary.self)
        XCTAssertNotNil(samples)
        
        // test basic stuff ....
        XCTAssertTrue(samples!["anInt"]!.typed() == 1234)
        XCTAssertTrue(samples!["aBool"]!.typed() == true)
        XCTAssertTrue(samples!["anotherBool"]!.typed() == false)
        XCTAssertTrue(samples!["aDouble"]!.typed() == 3.14)
        XCTAssertTrue(samples!["aString"]!.typed() == "booya")
        XCTAssertTrue(samples!["aNull"]!.typed() == NSNull())
        XCTAssertTrue((samples!["anArray"]! as! [JSConvertible]).count == 6)
        XCTAssertTrue((samples!["aDictionary"]!.typed(as: Dictionary.self))!.keys.count == 7)
        
        // test date ...
        let date = samples!["aDate"]!.typed(as: Date.self)!
        XCTAssertEqual(
            Int64(date.timeIntervalSince1970 * 1000), 1714564800000  // expected epoch ms for 2024-05-01T12:00:00Z
        )
        
        // test nested array stuff ...
        let array = samples!["anArray"]!.typed(as: Array.self)
        let subArray = array![4] as! [JSConvertible]
        let subDict = array![5] as! [String: JSConvertible]
        XCTAssertNotNil(array)
        XCTAssertNotNil(subArray)
        XCTAssertNotNil(subDict)
        
        XCTAssertTrue(array![0] is JSClass)
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
        XCTAssertTrue(nestedDict["anEdgeFn"]! is JSClass)
        XCTAssertTrue(nestedArray[0] as! String == "test1")
        XCTAssertTrue((nestedDict["anArray"] as! [JSConvertible]).count == 4)
    }


}
