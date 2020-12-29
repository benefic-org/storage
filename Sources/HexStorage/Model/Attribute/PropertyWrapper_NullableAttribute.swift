/// Convenience Property Wrapper API for defining a nullable Model Attribute.
@propertyWrapper public struct NullableAttribute<T: AttributeValue>: AttributeProtocol {
    
    public var cachedValue: T?
        
    var defaultValue: AttributeValue?
    
    var value: AttributeValue? {
        cachedValue
    }

    public var wrappedValue: Optional<T> {
        get { cachedValue }
        set { cachedValue = newValue }
    }
        
    public init(defaultValue: T? = nil) {
        self.defaultValue = defaultValue
        self.cachedValue = defaultValue
    }
    
<<<<<<< HEAD
    func metadata(with mirror: Mirror, descendent: Mirror.Child) -> AttributeMetadata? {
        // TODO: #ifdef out for !DEBUG.
        /// @see caller `Model.columns(filterByName:) ` for more info.
        guard let label = descendent.label else { return nil }
        return AttributeMetadata(name: label, type: T.type, nullable: false)
=======
    func metadata<M: RawModel>(with mirror: Mirror, descendent: Mirror.Child) -> AttributeMetadata<M>? {
        // TODO: #ifdef out for !DEBUG.
        /// @see caller `Model.columns(filterByName:) ` for more info.
        guard let label = descendent.label else { return nil }
        return AttributeMetadata(name: label, type: T.type, nullable: false, keyPath: \M.[checkedMirrorDescendant: label] as PartialKeyPath<M>)
>>>>>>> b478d27cfbdffa9632629d511abfe028bbd6d7c1
    }
}
