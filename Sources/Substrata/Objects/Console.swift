//
//  Console.swift
//  
//
//  Created by Brandon Sneed on 1/10/23.
//

import Foundation

internal class Console: JSExport, JSStatic {
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
        print(strings.joined(separator: " "))
        return nil
    }
}
