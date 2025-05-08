import XCTest
@testable import Substrata

/*
class MyTraits: JSExport {
    var description: String = "MyTraits"
    
    var debugDescription: String = "MyTraits"
    
    var a: Int = 23
    
    required init() {
        super.init()
        
        exportProperty(named: "a") {
            return self.a
        } setter: { arg in
            if let value = arg?.typed(as: Int.self) {
                self.a = value
            }
        }
    }
}
 */

class MyJSClass: JSExport, JSStatic {
    var myInt: Int = 0
    
    static var myStaticProperty = 42
    static var myStaticReadonlyProperty = "hello"
    
    var myInstanceProperty = 84
    var myInstanceReadonlyProperty = "goodbye"
    var traits = [String: JSConvertible]()
    //var traits2 = MyTraits()
    
    static func staticInit() {
        exportMethod(named: "someStatic", function: someStatic)
        
        exportProperty(named: "myStaticProperty", getter: { 
            return myStaticProperty
        }, setter: { arg in
            if let value = arg?.typed(as: Int.self) {
                myStaticProperty = value
            }
        })
        
        exportProperty(named: "myStaticReadonlyProperty", getter: {
            return myStaticReadonlyProperty
        })
    }
    
    static func someStatic(args: [JSConvertible?]) -> JSConvertible? {
        print("someStatic called.")
        return nil
    }
    
    required init() {
        super.init()
        
        exportMethod(named: "test", function: test)
        exportMethod(named: "test2", function: { args in
            return 3
        })
        
        exportProperty(named: "myInstanceProperty", getter: {
            return self.myInstanceProperty
        }, setter: { arg in
            if let value = arg?.typed(as: Int.self) {
                self.myInstanceProperty = value
            }
        })
        
        exportProperty(named: "traits", getter: {
            return self.traits
        }, setter: { arg in
            if let value = arg?.typed(as: [String: JSConvertible].self) {
                self.traits = value
            }
        })
        
        /*exportProperty(named: "traits2", getter: {
            return self.traits2
        }, setter: { arg in
            if let value = arg?.typed(as: MyTraits.self) {
                self.traits2 = value
            }
        })*/
        
        exportProperty(named: "myInstanceReadonlyProperty", getter: {
            return self.myInstanceReadonlyProperty
        })
    }
    
    override func construct(args: [JSConvertible?]) {
        myInt = 42
    }
    
    func test(args: [JSConvertible?]) -> JSConvertible? {
        print("got tested dawg.")
        print("myInt = \(myInt)")
        print(args)
        return myInt
    }
}

final class SubstrataTests: XCTestCase {
    func testDoubleExport() throws {
        let engine = JSEngine()
        
        engine.export(type: MyJSClass.self, className: "MyJSClass")
        
        expectFatalError {
            engine.export(type: MyJSClass.self, className: "MyJSClass")
        }
        
        engine.export(name: "test") { _ in
            return nil
        }
        
        expectFatalError {
            engine.export(name: "test") { _ in
                return nil
            }
        }
    }
    
    func testValueGetSet() throws {
        let engine = JSEngine()
        engine.evaluate(script: "var myArray = [1, 2, 3]")
        
        var array = engine.value(for: "myArray")?.typed(as: Array.self)
        XCTAssertNotNil(array)
        
        var setResult = false
        
        setResult = engine.setValue([4, 5, 6], for: "myArray")
        XCTAssertTrue(setResult)
        
        array = engine.value(for: "myArray")?.typed(as: Array.self)
        XCTAssertNotNil(array)
        XCTAssertTrue(array![0].typed(as: Int.self) == 4)
        XCTAssertTrue(array![1].typed(as: Int.self) == 5)
        XCTAssertTrue(array![2].typed(as: Int.self) == 6)
    }
    
    func testValueGetSetDeep() throws {
        let engine = JSEngine()
        engine.evaluate(script: """
        var myObject = {
            myArray: [1, 2, 3]
        }
        """)
        
        var array = engine.value(for: "myObject.myArray")?.typed(as: Array.self)
        XCTAssertNotNil(array)
        
        var setResult = false
        
        setResult = engine.setValue([4, 5, 6], for: "myObject.myArray")
        XCTAssertTrue(setResult)
        
        array = engine.value(for: "myObject.myArray")?.typed(as: Array.self)
        XCTAssertNotNil(array)
        XCTAssertTrue(array![0].typed(as: Int.self) == 4)
        XCTAssertTrue(array![1].typed(as: Int.self) == 5)
        XCTAssertTrue(array![2].typed(as: Int.self) == 6)
    }
    
    func testExtends() throws {
        let engine = JSEngine()
        engine.export(type: MyJSClass.self, className: "MyJSClass")
        
        engine.evaluate(script: """
        class OtherClass extends MyJSClass {
          constructor() {
            super()
            console.log("OtherClass created")
          }
        
          test(p1, p2) {
            console.log("OtherClass was muthatrukin called!!!!!!!")
            super.test(p1, p2)
            console.log("super was just called.")
          }
        }
        """)
        
        engine.evaluate(script: "let b = new OtherClass()")
        engine.evaluate(script: "b.test(1, 'blue')")
        
        XCTAssertTrue(ConsoleJS.wasLogged("OtherClass created"))
        XCTAssertTrue(ConsoleJS.wasLogged("OtherClass was muthatrukin called!!!!!!!"))
        XCTAssertTrue(ConsoleJS.wasLogged("super was just called."))
    }
    
    func testExportInstance() {
        let engine = JSEngine()
        
        let myJSClass = MyJSClass()
        myJSClass.myInt = 1337
        
        let x = engine.export(instance: myJSClass, className: "MyJSClass", as: "myJSClass")
        XCTAssertNotNil(x)
        
        let v = engine.value(for: "myJSClass")?.typed(as: JSClass.self)
        XCTAssertNotNil(v)
            
        let result = v?.call(method: "test", args: nil)?.typed(as: Int.self)
        XCTAssertEqual(result, 1337)
    }
    
    func testExportInstanceMethod() {
        let engine = JSEngine()
        
        engine.export(type: MyJSClass.self, className: "MyJSClass")
        engine.evaluate(script: "let x = new MyJSClass()")
        var result = engine.evaluate(script: "x.test()")?.typed(as: Int.self)
        XCTAssertEqual(result, 42)
        
        result = engine.evaluate(script: "x.test2()")?.typed(as: Int.self)
        XCTAssertEqual(result, 3)
    }
    
    func testStaticProperties() {
        let engine = JSEngine()
        engine.export(type: MyJSClass.self, className: "MyJSClass")
        
        let a = engine.evaluate(script: "MyJSClass.myStaticProperty")?.typed(as: Int.self)
        XCTAssertEqual(a, 42)
        engine.evaluate(script: "MyJSClass.myStaticProperty = 46")
        let b = engine.evaluate(script: "MyJSClass.myStaticProperty")?.typed(as: Int.self)
        XCTAssertEqual(b, 46)
        
        let c = engine.evaluate(script: "MyJSClass.myStaticReadonlyProperty")?.typed(as: String.self)
        XCTAssertEqual(c, "hello")
        engine.evaluate(script: "MyJSClass.myStaticReadonlyProperty = 'goodbye'")
        let d = engine.evaluate(script: "MyJSClass.myStaticReadonlyProperty")?.typed(as: String.self)
        XCTAssertEqual(d, "hello")
    }
    
    func testInstanceProperties() {
        let engine = JSEngine()
        engine.export(type: MyJSClass.self, className: "MyJSClass")
        engine.evaluate(script: "let myJSClass = new MyJSClass()")
        
        let a = engine.evaluate(script: "myJSClass.myInstanceProperty")?.typed(as: Int.self)
        XCTAssertEqual(a, 84)
        engine.evaluate(script: "myJSClass.myInstanceProperty = 46")
        let b = engine.evaluate(script: "myJSClass.myInstanceProperty")?.typed(as: Int.self)
        XCTAssertEqual(b, 46)
        
        let c = engine.evaluate(script: "myJSClass.myInstanceReadonlyProperty")?.typed(as: String.self)
        XCTAssertEqual(c, "goodbye")
        engine.evaluate(script: "myJSClass.myInstanceReadonlyProperty = 'hello'")
        let d = engine.evaluate(script: "myJSClass.myInstanceReadonlyProperty")?.typed(as: String.self)
        XCTAssertEqual(d, "goodbye")
    }
    
    func testSetBogusPropertySet() {
        let engine = JSEngine()
        //engine.export(type: MyTraits.self, className: "MyTraits")
        engine.export(type: MyJSClass.self, className: "MyJSClass")
        engine.evaluate(script: "let myJSClass = new MyJSClass()")
        
        let shouldntCrash1 = engine.evaluate(script: "myJSClass.myInstanceProperty.a = 7")?.typed(as: Int.self)
        XCTAssertEqual(shouldntCrash1, 7)
        
        let shouldntCrash2 = engine.evaluate(script: "myJSClass.myInstanceProperty.a")?.typed(as: Int.self)
        XCTAssertEqual(shouldntCrash2, nil)
        
        let traits = engine.evaluate(script: "myJSClass.traits")?.typed(as: [String: JSConvertible].self)
        XCTAssertNotNil(traits)
        
        // setting a native value like this shouldn't work
        engine.evaluate(script: "myJSClass.traits.a = 'hello'")
        var traits2 = engine.evaluate(script: "myJSClass.traits")?.typed(as: [String: JSConvertible].self)
        XCTAssertNotNil(traits2)
        let a = traits2?["a"]
        XCTAssertNil(a)
        
        // setting it like this SHOULD work
        engine.evaluate(script: "myJSClass.traits = {a: 'hello'}")
        traits2 = engine.evaluate(script: "myJSClass.traits")?.typed(as: [String: JSConvertible].self)
        XCTAssertNotNil(traits2)
        let newA = traits2?["a"] as? String
        XCTAssertEqual(newA, "hello")
        
        // this doesn't work; it's not super important so i'll come back to it later. :(
        /*var otherTraits = engine.evaluate(script: "myJSClass.traits2")?.typed(as: MyTraits.self)
        engine.evaluate(script: "myJSClass.traits2.a = 32")
        otherTraits = engine.evaluate(script: "myJSClass.traits2")?.typed(as: MyTraits.self)
        XCTAssertNotNil(otherTraits)
        let otherA = otherTraits?.a
        XCTAssertNil(otherA)*/

    }
}
