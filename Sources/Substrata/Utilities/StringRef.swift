//
//  StringRef.swift
//  
//
//  Created by Brandon Sneed on 1/10/23.
//

import Foundation
#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJavaScriptCore
#endif

internal class JSStringRefWrapper {
    var ref: JSStringRef
    
    init(value: String) {
        ref = value.withCString(JSStringCreateWithUTF8CString)!
    }
    
    init(value: JSStringRef) {
        ref = value
        JSStringRetain(ref)
    }
    
    deinit {
        JSStringRelease(ref)
    }
}

internal extension String {
    static func from(jsString: JSStringRef) -> String? {
        return String(utf16CodeUnits: JSStringGetCharactersPtr(jsString), count: JSStringGetLength(jsString))
    }
    
    var jsString: JSStringRefWrapper? {
        return JSStringRefWrapper(value: self)
    }
}
