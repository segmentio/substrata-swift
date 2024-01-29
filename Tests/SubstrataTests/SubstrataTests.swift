import XCTest
@testable import Substrata

class MyJSClass: JSExport, JSStatic {
    var myInt: Int = 0
    
    static func staticInit() {
        exportMethod(named: "someStatic", function: someStatic)
    }
    
    static func someStatic(args: [JSConvertible?]) -> JSConvertible? {
        print("someStatic called.")
        return nil
    }
    
    required init() {
        super.init()
        
        exportMethod(named: "test", function: test)
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
        
        setResult = engine.setValue(for: "myArray", value: [4, 5, 6])
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
        
        setResult = engine.setValue(for: "myObject.myArray", value: [4, 5, 6])
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
}
