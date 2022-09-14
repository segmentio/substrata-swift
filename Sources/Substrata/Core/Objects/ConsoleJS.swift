//
//  File.swift
//  
//
//  Created by Brandon Sneed on 6/8/22.
//

import Foundation

internal class ConsoleJS: JavascriptClass, JSConvertible {
    static var className: String = "console"
    static var staticProperties = [String : JavascriptProperty]()
    static var staticMethods: [String : JavascriptMethod] = [
        "log": JavascriptMethod({ _, this, params in
            guard let msg = params[0] as? String else { return nil }
            print("JSConsole: \(msg)")
            return nil
        })
    ]
    var instanceProperties = [String : JavascriptProperty]()
    var instanceMethods = [String : JavascriptMethod]()
    
    required init(context: JSContext, params: JSConvertible?...) throws {
        // nothin'
    }
}
