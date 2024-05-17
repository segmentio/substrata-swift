//
//  File.swift
//  
//
//  Created by Brandon Sneed on 1/14/24.
//

import Foundation

class ConsoleJS: JSExport, JSStatic {
    #if DEBUG
    static var logged = [String]()
    
    static func wasLogged(_ str: String) -> Bool {
        let result = logged.contains { s in
            return str == s
        }
        return result
    }
    #endif
    
    static func staticInit() {
        exportMethod(named: "log", function: log)
        exportMethod(named: "error", function: error)
    }
    
    static func log(args: [JSConvertible?]) -> JSConvertible? {
        let strings: [String] = args.map {
            if let str = $0 as? String {
                // skip .string for display since it adds quotes.
                return str
            } else {
                return String(humanized: ($0 as? JSInternalConvertible)?.string)
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
    
    static func error(args: [JSConvertible?]) -> JSConvertible? {
        let newArgs = ["JS ERROR: "] + args;
        _ = log(args: newArgs)
        return nil
    }
}
