//
//  SetMappingForSequence.swift
//  GlueKit
//
//  Created by Károly Lőrentey on 2016-10-07.
//  Copyright © 2016. Károly Lőrentey. All rights reserved.
//

extension ObservableSetType {
    public func flatMap<Result: Sequence>(_ key: @escaping (Element) -> Result) -> AnyObservableSet<Result.Iterator.Element> where Result.Iterator.Element: Hashable {
        return SetMappingForSequence<Self, Result>(parent: self, key: key).anyObservableSet
    }
}

class SetMappingForSequence<Parent: ObservableSetType, Result: Sequence>: SetMappingBase<Result.Iterator.Element> where Result.Iterator.Element: Hashable {
    typealias Element = Result.Iterator.Element
    let parent: Parent
    let key: (Parent.Element) -> Result

    init(parent: Parent, key: @escaping (Parent.Element) -> Result) {
        self.parent = parent
        self.key = key
        super.init()
        for e in parent.value {
            for new in key(e) {
                _ = self.insert(new)
            }
        }
        parent.updates.add(sink)
    }

    deinit {
        parent.updates.remove(sink)
    }

    private var sink: AnySink<SetUpdate<Parent.Element>> {
        return MethodSink(owner: self, identifier: 0, method: SetMappingForSequence.apply).anySink
    }

    private func apply(_ update: SetUpdate<Parent.Element>) {
        switch update {
        case .beginTransaction:
            beginTransaction()
        case .change(let change):
            var transformedChange = SetChange<Element>()
            for e in change.removed {
                for old in key(e) {
                    if self.remove(old) {
                        transformedChange.remove(old)
                    }
                }
            }
            for e in change.inserted {
                for new in key(e) {
                    if self.insert(new) {
                        transformedChange.insert(new)
                    }
                }
            }
            if !transformedChange.isEmpty {
                sendChange(transformedChange)
            }
        case .endTransaction:
            endTransaction()
        }
    }
}
