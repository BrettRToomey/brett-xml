import Core
import Node

final class BML {
    var name: Bytes
    var text: Bytes?
    var children: [(key: Bytes, value: [BML])]

    init(name: Bytes, text: Bytes? = nil) {
        self.name = name
        self.text = text
        children = []
    }
}

extension BML {
    // shorthand for adding attributes
    func add(key: Bytes, value: Bytes) {
        let sighting = BML(name: key, text: value)
        add(key: key, value: sighting)
    }

    func add(key: Bytes, value: BML) {
        for (index, child) in children.enumerated() {
            if child.key == key {
                var values = child.value
                values.append(value)
                children[index].value = values
                return
            }
        }

        //sighting not found
        children.append((key: key, value: [value]))
    }
}

extension BML {
    func makeNode() -> Node {
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
    }
}
