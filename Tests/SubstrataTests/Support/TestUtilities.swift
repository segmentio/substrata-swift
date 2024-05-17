//
//  File.swift
//  
//
//  Created by Brandon Sneed on 1/23/24.
//

import Foundation
import XCTest
@testable import Substrata

extension XCTestCase {
    func checkIfLeaked(_ instance: AnyObject, file: StaticString = #filePath, line: UInt = #line) {
        addTeardownBlock { [weak instance] in
            if instance != nil {
                print("Instance \(String(describing: instance)) is not nil")
            }
            XCTAssertNil(instance, "Instance should have been deallocated. Potential memory leak!", file: file, line: line)
        }
    }
    
    func expectFatalError(expectedMessage: String? = nil, testcase: @escaping () -> Void) {
        let expectation = self.expectation(description: "expectingFatalError")
        var assertionMessage: String? = nil
        
        // override fatalError. This will terminate thread when fatalError is called.
        FatalErrorUtil.replaceFatalError { message, _, _ in
            DispatchQueue.main.async {
                assertionMessage = message
                expectation.fulfill()
            }
            // Terminate the current thread after expectation fulfill
            Thread.exit()
            // Since current thread was terminated this code never be executed
            // This also fakes out the return type to be `@noreturn`.
            fatalError("It will never be executed")
        }
        
        // act, perform on separate thread to be able terminate this thread after expectation fulfill
        Thread(block: testcase).start()
        
        waitForExpectations(timeout: 0.1) { _ in
            // assert
            if expectedMessage != nil {
                XCTAssertEqual(assertionMessage, expectedMessage)
            }
            
            // clean up
            FatalErrorUtil.restoreFatalError()
        }
    }
}
