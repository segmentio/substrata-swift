//
//  ThreadingTests.swift
//  
//
//  Created by Brandon Sneed on 1/8/24.
//

import XCTest
@testable import Substrata

final class ThreadingTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testMultiEngineThreads() throws {
        let dg = DispatchGroup()
        for _ in 0..<1000 {
            dg.enter()
            DispatchQueue.global().async {
                autoreleasepool {
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
                    
                    let samples = r as? JSObject
                    XCTAssertNotNil(samples)
                    
                    // test basic stuff ....
                    XCTAssertTrue(samples!["anInt"]!.typed() == 1234)
                    XCTAssertTrue(samples!["aBool"]!.typed() == true)
                    XCTAssertTrue(samples!["anotherBool"]!.typed() == false)
                    XCTAssertTrue(samples!["aDouble"]!.typed() == 3.14)
                    XCTAssertTrue(samples!["aString"]!.typed() == "booya")
                    XCTAssertTrue(samples!["aNull"]!.typed() == NSNull())
                    XCTAssertTrue((samples!["anArray"]! as! [JSConvertible]).count == 6)
                    XCTAssertTrue((samples!["aDictionary"]! as! JSObject).keys.count == 7)
                    
                    // test nested array stuff ...
                    let array = samples!["anArray"]! as! [JSConvertible]
                    let subArray = array[4] as! [JSConvertible]
                    let subDict = array[5] as! JSObject
                    XCTAssertNotNil(array)
                    XCTAssertNotNil(subArray)
                    XCTAssertNotNil(subDict)
                    
                    XCTAssertTrue(array[0] is EdgeFunctionJS)
                    XCTAssertTrue(subArray[0] as! String == "blah1")
                    XCTAssertTrue(subDict["anotherBool"] as! Bool == false)
                    
                    // test nested dictionary stuff ...
                    let dict = samples!["aDictionary"]! as! JSObject
                    let nestedArray = dict["anArray"] as! [JSConvertible]
                    let nestedDict = dict["aDictionary"] as! JSObject
                    XCTAssertNotNil(dict)
                    XCTAssertNotNil(nestedArray)
                    XCTAssertNotNil(nestedDict)
                    
                    XCTAssertTrue(dict["aDouble"] as! Double == 3.14)
                    XCTAssertTrue(nestedDict["anEdgeFn"]! is EdgeFunctionJS)
                    XCTAssertTrue(nestedArray[0] as! String == "test1")
                    XCTAssertTrue((nestedDict["anArray"] as! [JSConvertible]).count == 4)
                    
                    dg.leave()
                }
            }
        }
        
        dg.wait()
        print("wait finished.")
    }

    func testSingleEngineMultiThreads() throws {
        let engine = JSEngine()
        engine.exceptionHandler = { error in
            XCTFail()
            print(error)
        }
        
        engine.export(type: EdgeFunctionJS.self, className:"EdgeFunction")
        
        let bundle = Bundle.module
        let bundleURL = bundle.url(forResource: "ConversionTestData", withExtension: "js")
        engine.loadBundle(url: bundleURL!)
        
        let dg = DispatchGroup()
        for _ in 0..<1000 {
            dg.enter()
            DispatchQueue.global().async {
                autoreleasepool {
                    let r = engine.value(for: "conversionSamples")
                    XCTAssertNotNil(r)
                    
                    let samples = r as? JSObject
                    XCTAssertNotNil(samples)
                    
                    // test basic stuff ....
                    XCTAssertTrue(samples!["anInt"]!.typed() == 1234)
                    XCTAssertTrue(samples!["aBool"]!.typed() == true)
                    XCTAssertTrue(samples!["anotherBool"]!.typed() == false)
                    XCTAssertTrue(samples!["aDouble"]!.typed() == 3.14)
                    XCTAssertTrue(samples!["aString"]!.typed() == "booya")
                    XCTAssertTrue(samples!["aNull"]!.typed() == NSNull())
                    XCTAssertTrue((samples!["anArray"]! as! [JSConvertible]).count == 6)
                    XCTAssertTrue((samples!["aDictionary"]! as! JSObject).keys.count == 7)
                    
                    // test nested array stuff ...
                    let array = samples!["anArray"]! as! [JSConvertible]
                    let subArray = array[4] as! [JSConvertible]
                    let subDict = array[5] as! JSObject
                    XCTAssertNotNil(array)
                    XCTAssertNotNil(subArray)
                    XCTAssertNotNil(subDict)
                    
                    XCTAssertTrue(array[0] is EdgeFunctionJS)
                    XCTAssertTrue(subArray[0] as! String == "blah1")
                    XCTAssertTrue(subDict["anotherBool"] as! Bool == false)
                    
                    // test nested dictionary stuff ...
                    let dict = samples!["aDictionary"]! as! JSObject
                    let nestedArray = dict["anArray"] as! [JSConvertible]
                    let nestedDict = dict["aDictionary"] as! JSObject
                    XCTAssertNotNil(dict)
                    XCTAssertNotNil(nestedArray)
                    XCTAssertNotNil(nestedDict)
                    
                    XCTAssertTrue(dict["aDouble"] as! Double == 3.14)
                    XCTAssertTrue(nestedDict["anEdgeFn"]! is EdgeFunctionJS)
                    XCTAssertTrue(nestedArray[0] as! String == "test1")
                    XCTAssertTrue((nestedDict["anArray"] as! [JSConvertible]).count == 4)
                    
                    dg.leave()
                    
                    print("another thread done.")
                }
            }
        }
        
        dg.wait()
        print("wait finished.")
    }
}
