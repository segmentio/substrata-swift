# Substrata-Swift
Small, Efficient, Easy.  Javascript Engine for Swift.

Using JavascriptCore (and other engines in the future) has been simplified.  No more
messing with JSValues, type conversion and messy call sites to use Javascript.

Substrata Swift is currently only available in Beta

### Quick Start

Values are converted automatically to the appropriate types
as needed.  Calls into JavascriptCore are all synchronized on
the same serial dispatch queue.

```swift
// get a shared engine instance
let engine = JSEngine.shared

// set the error handler we want to use
engine.errorHandler = { error in
   print("javascript error: \(error)")
}

// execute some js
let result = engine.execute(script: "1 + 2;") as? Int
if result == 3 {
   // success!
}
```

### Loading a Javascript bundle from disk

Load a bundle from disk.  Only accepts file URLs.  Any downloading of javascript
bundles must be done upstream by the caller.  A completion block will be executed
when done (if specified).
     
 ```swift
 engine.loadBundle(url: myBundleURL) { error in
    if error {
        print("oh noes, we failed: \(error))
        return
    } else {
        success = true
    }
 }
 ```
 
### Expose and Extend

Expose a native class to Javascript by name.
 
Classes that will be exposed need to have a protocol marked with JSExports
to allow any methods or properties to be accessible.
 
If you intend on allowing the class to be used as a return value or parameters
it may also be useful to conform to JSConvertible.
 
 ```swift
 protocol MyClassExports: JSExport {
    var myValue: Int
    func doSomething() -> Bool
 }
 
 @objc
 class MyClass: NSObject, MyClassExports, JSConvertible {
    var myValue: Int = 5
    func doSomething() -> Bool { return true }
 }
 
 engine.expose(classType: MyClass.type, name: "MyClass")
 
 let something = engine.execute(script: "var c = new MyClass(); c.doSomething();") as? Bool
 if something {
    // success!
 }
 
 let jsClassInstance = engine.execute(script: "c;") as? MyClass
 if jsClassInstance {
    jsClassInstance.doSomething()
 }
 ```

Expose a native function to Javascript by name.
 
 ```swift
 let quadruple: @convention(block) (Int) -> Int = { input in
     return input * 4
 }
 
 engine.expose(function: quadruple, name: "quadruple")
 let result = engine.execute(script: "quadruple(3);") as? Int
 if result == 12 {
    // success!
 }
 ```

Extend an existing Javascript object.

 ```swift
 let doSomething: @convention(block) () -> Void = {
     print("hello")
 }
 
 engine.extend(object: "console", function: doSomething, name: "doSomething")
 ```

### Access and Use  Javascript

Call a Javascript function directly by name.  Javascript handles the name resolution.
 
 ```swift
 let result = engine.call(functionName: "thing.addNumbers", params: [1, 2, 3]) as? Int
 if result == 6 {
    // success!
 }
 ```
 
Just run some Javascript code freely...

```swift
let something = engine.execute(script: "var c = new MyClass(); c.doSomething();") as? Bool
if something {
	// success!
}
```

Grab and Set some value on the global object.

```swift
engine.setObject(key: "numberArray", value: [1, 2, 3])
let numnums = engine.object(key: "numberArray") as? [Int]
```

## Why not use JavascriptCore directly?

Cuz it's kind of a pain.  Much of JavascriptCore puts the onus to make any
niceties, like type conversion, logic checks, etc. on the caller and tends
to lead to some code that looks like spaghetti.

We also wanted to set ourselves up a little for a world where JavascriptCore
isn't the only option without rewriting the calling code.

## License

MIT License

Copyright (c) 2022 Segment

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

