//
//  File.swift
//  
//
//  Created by Brandon Sneed on 5/26/22.
//

import Foundation

#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

public class JSArray: JSObject {
    public override var value: JSConvertible? {
        var result = [Any]()
        for i in 0..<count {
            if let v = self[i].value { result.append(v) }
        }
        return result as? [JSConvertible]
    }
    
    public override func value<T: JSConvertible>(_ type: T.Type) -> T? {
        // try a little harder for numbers ...
        // they could be asking for an Int where
        // we only deal with Double internally.
        guard let v = value else { return nil }
        // this will pass if the contents are ALL numbers
        // if not, return w/ a test to T.
        guard let array = v as? [Double] else { return v as? T }
        if type.self == [Double].self { return array as? T }
        // now we know they're all numbers, it's safe to do a straight conversion.
        if type.self == [Int].self {
            return array.map { Int($0) } as? T
        }
        if type.self == [UInt].self {
            return array.map { UInt($0) } as? T
        }
        if type.self == [Float].self {
            return array.map { Float($0) } as? T
        }
        
        return array as? T
    }

    
    public override func jsDescription() -> String? {
        if let v = value { return "\(v)" }
        return nil
    }
}

extension JSArray {
    public var count: Int {
        return self["length"].value(Int.self) ?? 0
    }
    
    public subscript(index: Int) -> JSPrimitive {
        get {
            let result = JSObjectGetPropertyAtIndex(context.ref, ref, UInt32(index), nil)
            return result.map { JSPrimitive.construct(from: $0, context: context) } ?? context.undefined
        }
        set {
            JSObjectSetPropertyAtIndex(context.ref, ref, UInt32(index), newValue.ref, nil)
        }
    }
}

extension Array: JSConvertible /*where Element: JSConvertible*/ {
    public func jsValue(context: JSContext) -> JSPrimitive {
        guard let ref = JSObjectMakeArray(context.ref, 0, nil, nil) else { return context.undefined }
        let array = JSArray(context: context, ref: ref)
        for (index, value) in enumerated() {
            if let value = value as? JSConvertible {
                array[index] = value.jsValue(context: context)
            } else if let value = value as? JSPrimitive {
                array[index] = value
            }
        }
        return array
    }
}

extension NSArray: JSConvertible {
    public func jsValue(context: JSContext) -> JSPrimitive {
        guard let ref = JSObjectMakeArray(context.ref, 0, nil, nil) else { return context.undefined }
        let array = JSArray(context: context, ref: ref)
        for (index, value) in enumerated() {
            if let value = value as? JSConvertible {
                array[index] = value.jsValue(context: context)
            } else if let value = value as? JSPrimitive {
                array[index] = value
            }
        }
        return array
    }
}
