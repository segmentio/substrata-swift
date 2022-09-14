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

public class JSUndefined: JSPrimitive {
    convenience public init(context: JSContext) {
        self.init(context: context, ref: JSValueMakeUndefined(context.ref))
    }
    
    public override var value: JSConvertible? {
        return nil
    }
}

extension JSContext {
    public var undefined: JSUndefined {
        return JSUndefined(context: self)
    }
}
