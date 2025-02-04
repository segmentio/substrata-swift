//
//  File.swift
//  
//
//  Created by Brandon Sneed on 1/24/24.
//

import Foundation
import SubstrataQuickJS

@dynamicMemberLookup
internal class Builtins {
    internal var functions = [String: JSFunction?]()
    
    init(engine: JSEngine) {
        engine.evaluate(script: """
        function _hasMethod (obj, name) {
          const desc = Object.getOwnPropertyDescriptor (obj, name);
          return !!desc && typeof desc.value === 'function';
        }

        function _getInstanceMethodNames (obj, stop) {
          let output = {};
          let proto = Object.getPrototypeOf (obj);
          while (proto && proto !== stop) {
            Object.getOwnPropertyNames (proto)
              .forEach (name => {
                if (name !== 'constructor' && !name.includes("_")) {
                  if (_hasMethod (proto, name)) {
                    //array.push (obj[name]);
                    output[name] = obj[name];
                  }
                }
              });
            proto = Object.getPrototypeOf (proto);
          }
          return output;
        }
        """, evaluator: "JSEngine.Builtins")
        
        if let getInstanceMethodNames = engine.evaluate(script: "_getInstanceMethodNames", evaluator: "JSEngine.Builtins.evaluate")?.typed(as: JSFunction.self) {
            functions["_getInstanceMethodNames"] = getInstanceMethodNames
        }
    }
    
    func free() {
        functions.removeAll()
    }
    
    subscript(dynamicMember member: String) -> JSFunction? {
        return functions[member, default: nil]
    }
}
