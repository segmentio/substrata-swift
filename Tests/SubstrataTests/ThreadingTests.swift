//
//  ThreadingTests.swift
//  
//
//  Created by Brandon Sneed on 1/8/24.
//

import XCTest

final class ThreadingTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testMultiEngineThreads() throws {
        /*let dg = DispatchGroup()
        for _ in 0..<10000 {
            dg.enter()
            DispatchQueue.global().async {
                let conversionTest = ConversionTests()
                try? conversionTest.testMassConversionOut()
                dg.leave()
            }
        }
        
        dg.wait()
        print("wait finished.")*/
    }

}
