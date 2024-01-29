//
//  Console.swift
//  
//
//  Created by Brandon Sneed on 1/10/23.
//

import Foundation

internal class Console: JSExport, JSStatic {
    #if DEBUG
    static var logged = [String]()
    #endif
    
    static func staticInit() {
        export(method: log, as: "log")
    }
    
    static func log(args: [JSConvertible?]) -> JSConvertible? {
        let strings: [String] = args.map {
            if let str = $0 as? String {
                // skip .string for display since it adds quotes.
                return str
            } else {
                return String(humanized: $0?.string)
            }
        }
        let output = strings.joined(separator: " ")
        #if DEBUG
        if isUnitTesting {
            logged.append(output)
        }
        #endif
        print(output)
        return nil
    }
}
