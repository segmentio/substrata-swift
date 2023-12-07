//
//  File.swift
//  
//
//  Created by Brandon Sneed on 1/10/23.
//

import Foundation
@testable import Substrata

class EdgeFunctionJS: JSExport, JSStatic {
    static var myStaticBool: Bool? = true
    var myBool: Bool? = false
    
    static func reset() { myStaticBool = true }
    
    static func staticInit() {
        export(method: getMyStaticBool, as: "getMyStaticBool")
        export(method: setMyStaticBool, as: "setMyStaticBool")
        export(method: myStaticMethod, as: "myStaticMethod")
    }
    
    required init() {
        super.init()
        
        export(property: JSProperty(getter: {
            print("myBool read")
            return self.myBool
        }, setter: { value in
            print("myBool set")
            self.myBool = value?.typed()
        }), as: "myBool")
        
        export(method: myInstanceMethod, as: "myInstanceMethod")
        export(method: execute, as: "execute")
    }
    
    override func construct(args: [JSConvertible]) {
        print("constructor called")
        let b: Bool = args.typed(as: Bool.self, index: 0)!
        print("constructor arg0 = \(b)")
    }
    
    static func myStaticMethod(args: [JSConvertible]) -> JSConvertible? {
        print("myStaticMethod Called")
        let b: Bool = args.typed(as: Bool.self, index: 0)!
        print("myStaticMethod arg0 = \(b)")
        return true
    }
    
    static func getMyStaticBool(args: [JSConvertible]) -> JSConvertible? {
        print("getMyStaticBool Called")
        return myStaticBool
    }
    
    static func setMyStaticBool(args: [JSConvertible]) -> JSConvertible? {
        print("getMyStaticBool Called")
        let b: Bool = args.typed(as: Bool.self, index: 0)!
        myStaticBool = b
        return nil
    }
    
    func myInstanceMethod(args: [JSConvertible]) -> JSConvertible? {
        print("myInstanceMethod Called")
        let b: Bool = args.typed(as: Bool.self, index: 0)!
        print("myInstanceMethod arg0 = \(b)")
        return true
    }
    
    func execute(args: [JSConvertible]) -> JSConvertible? {
        print("execute Called")
        let s: String = args.atIndex(0)!.typed()!
        print("execute arg0 = \(s)")
        return true
    }
}

func myFunction(args: [JSConvertible]) -> JSConvertible? {
    print("myFunction called")
    print("myFunction arg0 = \(String(humanized: args.index(0)?.string))")
    return true
}

class AnalyticsJS: JSExport, JSStatic {
    static func staticInit() {
        /*export(property: JSProperty(getter: {
            return myStaticProperty
        }, setter: { value in
            myStaticProperty = value?.typed()
        }), as: "myStaticProperty")*/
        
        export(method: { args in
            print("hello")
            return nil
        }, as: "myStaticMethod")
    }
    
    required init() {
        super.init()
        
        export(property: JSProperty(getter: {
            return ["email": "blah@blah.com"]
        }, setter: nil), as: "email")
        
        export(property: JSProperty(getter: {
            return "blah"
        }, setter: nil), as: "userId")
        
        export(property: JSProperty(getter: {
            return "0123456789"
        }, setter: nil), as: "anonymousId")
        
        export(property: JSProperty(getter: {
            return self.writeKey
        }, setter: nil), as: "writeKey")
        
        export(method: { args in
            print("track called with params: \(args)")
            return 1
        }, as: "track")
        export(method: { args in
            print("identify called with params: \(args)")
            return 2
        }, as: "identify")
        export(method: { args in
            print("screen called with params: \(args)")
            return 3
        }, as: "screen")
        export(method: { args in
            print("group called with params: \(args)")
            return 4
        }, as: "group")
        export(method: { args in
            print("alias called with params: \(args)")
            return 5
        }, as: "alias")
        export(method: { args in
            //return EdgeFunctionJS()
            return nil
        }, as: "testObject")
    }
    
    override func construct(args: [JSConvertible]) {
        writeKey = args.typed(as: String.self, index: 0)
    }
    
    var writeKey: String? = nil
    static var myStaticProperty: Bool? = false
    
    
}
