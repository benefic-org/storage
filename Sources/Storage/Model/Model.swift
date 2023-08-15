//
// Copyright © 2021 Benefic Technologies Inc. All rights reserved.
// License Information: https://github.com/oxcug/hex/blob/master/LICENSE

import Foundation

protocol OpaqueModel {
    associatedtype Conformance
}

@dynamicMemberLookup
public final class Model<Schema: SchemaRepresentable> {
    
    typealias Schema = Schema
    
    public var attributeValueStorage = [String: AttributeValue?]()
    
    var attributeTransformers = [String: AttributeTransformer]()
    
    func populateAttributeTransformers() {
        Self.Schema.attributeMetadatas().forEach {
            attributeTransformers[$0.name] = $0.transformer
        }
    }
    
    func populateAttributeValueStorage(values: [String: AttributeValue?]) {
        values.forEach {
            if let fn = attributeTransformers[$0.key] {
                attributeValueStorage[$0.key] = (fn.set($0.value!) as? any AttributeValue)
            } else {
                attributeValueStorage[$0.key] = $0.value
            }
        }
    }
    
    func retreieveAttributeValueFromStorage(for key: String) -> AttributeValue? {
        guard let value = attributeValueStorage[key] else { return nil }
        if let fn = attributeTransformers[key] {
            return (fn.get(value) as! any AttributeValue)
        } else {
            return value
        }
    }
    
    public required init(with value: Schema) {
        var values = [String: AttributeValue?]()
        let m = Mirror(reflecting: value)
        
        m.children
            .filter { $0.label?.starts(with: "_") ?? false }
            .forEach {
                guard let sub = $0.label?.dropFirst(1) else { return }
                let key = String(sub)
                
                values[key] = ($0.value as? AttributeProtocol)?.value
            }
        
        populateAttributeTransformers()
        populateAttributeValueStorage(values: values)
    }
    
    public required init(from attributeValues: [String: AttributeValue?]) {
        populateAttributeTransformers()
        self.attributeValueStorage = attributeValues
    }
    
    public subscript<T>(dynamicMember key: String) -> T {
        print("Searching using key: \(key) (storage: \(attributeValueStorage))")
        return retreieveAttributeValueFromStorage(for: key) as! T
    }
}
