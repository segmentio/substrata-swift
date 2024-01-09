//
//  Extensions.swift
//  
//
//  Created by Brandon Sneed on 1/11/23.
//

import Foundation
#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJavaScriptCore
#endif

extension Double {
    internal var isInteger: Bool {
        return truncatingRemainder(dividingBy: 1) == 0
    }
}

extension String {
    internal init<T>(humanized instance: T?) {
        guard let i = instance else {
            self.init("nil")
            return
        }
        self.init(describing: i)
    }
}


// Brought over from Decimal.swift; These methods are internal there, but we need them.
// see: https://github.com/apple/swift-corelibs-foundation/blob/cfac32b92d5fb62a651967cf22756352179b58ba/Sources/Foundation/Decimal.swift#L108
extension Decimal {
    fileprivate subscript(index: UInt32) -> UInt16 {
        get {
            switch index {
            case 0: return _mantissa.0
            case 1: return _mantissa.1
            case 2: return _mantissa.2
            case 3: return _mantissa.3
            case 4: return _mantissa.4
            case 5: return _mantissa.5
            case 6: return _mantissa.6
            case 7: return _mantissa.7
            default: fatalError("Invalid index \(index) for _mantissa")
            }
        }
        set {
            switch index {
            case 0: _mantissa.0 = newValue
            case 1: _mantissa.1 = newValue
            case 2: _mantissa.2 = newValue
            case 3: _mantissa.3 = newValue
            case 4: _mantissa.4 = newValue
            case 5: _mantissa.5 = newValue
            case 6: _mantissa.6 = newValue
            case 7: _mantissa.7 = newValue
            default: fatalError("Invalid index \(index) for _mantissa")
            }
        }
    }

    internal var doubleValue: Double {
        if _length == 0 {
            return _isNegative == 1 ? Double.nan : 0
        }

        var d = 0.0
        for idx in (0..<min(_length, 8)).reversed() {
            d = d * 65536 + Double(self[idx])
        }

        if _exponent < 0 {
            for _ in _exponent..<0 {
                d /= 10.0
            }
        } else {
            for _ in 0..<_exponent {
                d *= 10.0
            }
        }
        return _isNegative != 0 ? -d : d
    }
}

extension JSValueRef {
    func isClass(context: JSContextRef) -> Bool {
        let method = "constructor".jsValue(context: context)
        if let constructor = JSObjectGetProperty(context, self, method, nil),
           let s = String.from(jsValue: constructor, context: context) {
            return s.hasPrefix("class")
        }
        return false
    }
}

extension JSEngine {
    @discardableResult
    internal func call(functionName: String, this: JSValueRef, args: [JSConvertible?]) -> JSConvertible? {
        var result: JSConvertible? = nil
        jsQueue.sync {
            let name = JSStringRefWrapper(value: functionName)
            let value = JSObjectGetProperty(globalContext, this, name.ref, &exception)
            let args = args.map { jsTyped($0, context: self.globalContext) }
            let v = JSObjectCallAsFunction(globalContext, value, this, args.count, args.isEmpty ? nil : args, &exception)
            result = valueRefToType(context: globalContext, value: v)
            makeCallableIfNecessary(result)
        }
        return result
    }
    
    @discardableResult
    internal func run(closure: () -> JSConvertible?) -> JSConvertible? {
        var result: JSConvertible?
        jsQueue.sync {
            result = closure()
        }
        return result
    }
}
