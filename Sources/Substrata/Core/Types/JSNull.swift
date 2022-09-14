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

public class JSNull: JSPrimitive {
    convenience public init(context: JSContext) {
        self.init(context: context, ref: JSValueMakeNull(context.ref))
    }

    public override var value: JSConvertible? {
        return NSNull()
    }
}

extension NSNull: JSConvertible {
    public func jsValue(context: JSContext) -> JSPrimitive {
        let null = JSNull(context: context)
        return null
    }
}

