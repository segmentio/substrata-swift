//
//  File.swift
//  
//
//  Created by Brandon Sneed on 6/13/22.
//

import Foundation

#if DEBUG

internal class JSLeaks {
    @WeakElements static var objects = [AnyObject?]()
    static var leaked = {
        return objects.filter { object in
            if object != nil { return true }
            return false
        }
    }
}

internal var isUnitTesting: Bool = {
    // this will work on apple platforms, but fail on linux.
    if NSClassFromString("XCTestCase") != nil {
        return true
    }
    // this will work on linux and apple platforms, but not in anything with a UI
    // because XCTest doesn't come into the call stack till much later.
    let matches = Thread.callStackSymbols.filter { line in
        return line.contains("XCTest") || line.contains("xctest")
    }
    if matches.count > 0 {
        return true
    }
    // this will work on CircleCI to correctly detect test running.
    if ProcessInfo.processInfo.environment["CIRCLE_WORKFLOW_WORKSPACE_ID"] != nil {
        return true
    }
    // couldn't see anything that indicated we were testing.
    return false
}()

struct WeakObject<Object: AnyObject> { weak var object: Object? }

@propertyWrapper
struct WeakElements<Collect, Element> where Collect: RangeReplaceableCollection, Collect.Element == Optional<Element>, Element: AnyObject {
    private var weakObjects = [WeakObject<Element>]()

    init(wrappedValue value: Collect) { save(collection: value) }

    private mutating func save(collection: Collect) {
        weakObjects = collection.map { WeakObject(object: $0) }
    }

    var wrappedValue: Collect {
        get { Collect(weakObjects.map { $0.object }) }
        set (newValues) { save(collection: newValues) }
    }
}

#endif
