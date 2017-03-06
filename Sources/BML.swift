import Core
import Node

public typealias XML = BML

public final class BML {
    var _name: Bytes
    var _value: Bytes?

    var nameCache: String?
    var valueCache: String?
    
    public var name: String {
        if let nameCache = nameCache {
            return nameCache
        } else {
            let result = _name.fasterString
            nameCache = result
            return result
        }
    }
    
    public var value: String? {
        guard _value != nil else {
            return nil
        }
        
        if let valueCache = valueCache {
            return valueCache
        } else {
            let result = _value!.fasterString
            valueCache = result
            return result
        }
    }
    
    public var attributes: [BML]
    public var children: [BML]

    init(
        name: Bytes,
        value: Bytes? = nil,
        attributes: [BML] = [],
        children: [BML] = []
    ) {
        _name = name
        _value = value
        self.attributes = attributes
        self.children = children
    }
    
    convenience init(
        name: String,
        value: String? = nil,
        attributes: [BML] = [],
        children: [BML] = []
    ) {
        self.init(
            name: name.bytes,
            value: value?.bytes,
            attributes: attributes,
            children: children
        )
    }
}

extension BML {
    func addChild(key: Bytes, value: Bytes) {
        let sighting = BML(name: key, value: value)
        add(child: sighting)
    }

    func addAttribute(key: Bytes, value: Bytes) {
        let sighting = BML(name: key, value: value)
        add(attribute: sighting)
    }
    
    func add(child: BML) {
        children.append(child)
    }
    
    func add(attribute: BML) {
        attributes.append(attribute)
    }
}

extension BML {
    public func children(named name: String) -> [BML] {
        let name = name.bytes
        return children.filter {
            $0._name == name
        }
    }
    
    public func firstChild(named name: String) -> BML? {
        let name = name.bytes
        
        for child in children {
            if child._name == name {
                return child
            }
        }
        
        return nil
    }
    
    public func attributes(named name: String) -> [BML] {
        let name = name.bytes
        return children.filter {
            $0._name == name
        }
    }
    
    public func firstAttribute(named name: String) -> BML? {
        let name = name.bytes
        
        for attribute in attributes {
            if attribute._name == name {
                return attribute
            }
        }
        
        return nil
    }
}

extension BML {
    public subscript(_ name: String) -> BML? {
        return firstChild(named: name)
    }
}

extension BML {
    /*func makeNode() -> Node {
        // String
        if let text = text?.fasterString, children.count == 0 {
            return .string(text)
        }

        // Array
        if children.count == 1, text == nil, children[0].value.count > 1 {
            return .array(
                children[0].value.map {
                    $0.makeNode()
                }
            )
        }

        // Object
        var object = Node.object([:])
        
        if let text = text?.fasterString {
            object["text"] = .string(text)
        }

        children.forEach {
            let subObject: Node
            if $0.value.count == 1 {
                subObject = $0.value[0].makeNode()
            } else {
                subObject = .array(
                    $0.value.map {
                        $0.makeNode()
                    }
                )
            }
            object[$0.key.fasterString] = subObject
        }

        return object
    }*/
}
