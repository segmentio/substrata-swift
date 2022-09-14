//
//  MockAnalytics.swift
//  
//
//  Created by Brandon Sneed on 4/28/22.
//

import Foundation
import Substrata

class EdgeFunctionJS: JavascriptClass, JSConvertible {
    static var staticProperties: [String : JavascriptProperty] = [:]
    static var staticMethods: [String : JavascriptMethod] = [:]
    var instanceProperties: [String : JavascriptProperty] = [:]
    var instanceMethods: [String : JavascriptMethod] = [:]
    
    static var className: String = "EdgeFunction"
    
    required init(context: JSContext, params: JSConvertible?...) throws {
        print("hello")
    }
}

class AnalyticsJS: JavascriptClass, JSConvertible {
    static var className: String = "Analytics"
    
    static var staticProperties: [String: JavascriptProperty] = [
        "myStaticProperty": JavascriptProperty(
            get: { _, _ in
                return myStaticProperty
            },
            set: { _, _, value in
                myStaticProperty = value as? Bool
            }
        )
    ]
    
    static var staticMethods: [String: JavascriptMethod] = [
        "myStaticMethod": JavascriptMethod { _, this, params in
            print("hello")
            return nil
        }
    ]
    
    var instanceProperties: [String: JavascriptProperty] = [
        "traits": JavascriptProperty(get: { _, _ in return ["email": "blah@blah.com"] }),
        "userId": JavascriptProperty(get: { _, _ in return "blah" }),
        "anonymousId": JavascriptProperty(get: { _, _ in return "0123456789" })
    ]
    
    var instanceMethods: [String: JavascriptMethod] = [
        "track": JavascriptMethod { _, _, params in print("track called with params: \(params)"); return nil },
        "identify": JavascriptMethod { _, _, params in print("identify called with params: \(params)"); return nil },
        "screen": JavascriptMethod { _, _, params in print("screen called with params: \(params)"); return nil },
        "group": JavascriptMethod { _, _, params in print("group called with params: \(params)"); return nil },
        "alias": JavascriptMethod { _, _, params in print("alias called with params: \(params)"); return nil },
        "testObject": JavascriptMethod { weakSelf, this, params in
            guard let instance = weakSelf as? AnalyticsJS else { return nil }
            guard let context = instance.context else { return nil }
            return try? EdgeFunctionJS(context: context, params: nil)
        }
    ]
    
    let writeKey: String
    static var myStaticProperty: Bool? = false
    weak var context: JSContext?
    
    required init(context: JSContext, params: JSConvertible?...) throws {
        guard let w = params[0] as? String else { throw "No writekey was specified" }
        self.writeKey = w
        self.context = context
    }
    
}

