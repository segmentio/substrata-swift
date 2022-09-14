//
//  File.swift
//  
//
//  Created by Brandon Sneed on 5/31/22.
//

import Foundation

#if canImport(JavaScriptCore)
import JavaScriptCore
#else
import CJSCore
#endif

public protocol JSExport: AnyObject, JSConvertible {
    static var className: String { get }
    init(context: JSContext, params: [JSPrimitive]?) throws
}
