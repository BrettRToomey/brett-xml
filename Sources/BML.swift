import Core
import Node

let whitespace: Set<Byte> = [.newLine, .horizontalTab, .space, .carriageReturn]
let attributeTerminators = whitespace.union([.equals])
let attributeValueTerminators = whitespace.union([.quote])
let tagNameTerminators = whitespace.union([.greaterThan])

extension Byte {
    /// <
    public static let lessThan: Byte = 0x3C
    
    /// >
    public static let greaterThan: Byte = 0x3E
    
    /// !
    public static let exclamationPoint: Byte = 0x21
}

extension Byte {
    var hex: String {
        return "0x" + String(self, radix: 16).uppercased()
    }
}

public struct XMLParser {
    public enum Error: Swift.Error {
        case malformedXML(String)
        case unexpectedEndOfFile
    }
    
    var scanner: Scanner<Byte>
    
    init(scanner: Scanner<Byte>) {
        self.scanner = scanner
    }
}

extension XMLParser {
    public static func parse(_ xml: String) throws -> Node {
        return try parse(xml.bytes)
    }
    
    public static func parse(_ bytes: Bytes) throws -> Node {
        var parser = XMLParser(scanner: Scanner(bytes))
        var rootNode = Node.object([:])

        while let sighting = try parser.extractTag() {
           rootNode[sighting.name.fasterString] = sighting.makeNode()
        }

        return rootNode
    }
}

extension XMLParser {
    mutating func extractTag() throws -> BML? {
        skipWhitespace()
        
        guard scanner.peek() != nil else {
            return nil
        }
        
        guard scanner.pop() == .lessThan else {
            throw Error.malformedXML("Expected tag")
        }

        guard let byte = scanner.peek() else {
            throw Error.unexpectedEndOfFile
        }
        
        switch byte {
        // Header
        case Byte.questionMark:
            extractHeader()
            return try extractTag()
        
        // Comment
        case Byte.exclamationPoint:
            eatComment()
            return try extractTag()
        
        // Object
        default:
            return try extractObject()
        }
    }
}

extension XMLParser {
    mutating func extractHeader() {
        assert(scanner.peek() == .questionMark)
        scanner.pop()
        
        skip(until: .questionMark)
        if scanner.peek(aheadBy: 1) == .greaterThan {
            scanner.pop(2)
        } else {
            scanner.pop()
        }
    }
    
    mutating func extractObject() throws -> BML? {
        // TODO(Brett):
        // I shouldn't have to do this, figure out which state is throwing
        // the pointer into a garbage state
        if scanner.peek() == .lessThan {
            scanner.pop()
        }
        
        let name = consume(until: tagNameTerminators)
        
        let sighting = BML(name: name)

        let (attributes, selfClosing) = try extractAttributes()
        attributes.forEach {
            sighting.add(key: $0.name, value: $0.value)
        }
        
        outerLoop: while scanner.peek() != nil {
            skipWhitespace()

            guard !selfClosing else {
                break outerLoop
            }

            guard let byte = scanner.peek() else {
                continue
            }

            switch byte {
            case Byte.lessThan:
                // closing tag
                if scanner.peek(aheadBy: 1) == .forwardSlash {
                    if isClosingTag(name) {
                        break outerLoop
                    } else {
                        throw Error.malformedXML("Expected closing tag </\(name.string)>")
                    }
                } else { // new object
                    guard let subObject = try extractObject() else {
                        break outerLoop
                    }
                    sighting.add(key: subObject.name, value: subObject)
                }
                
            default:
                sighting.text = extractTagText()
            }
        }
        
        return sighting
    }
    
    mutating func extractTagText() -> Bytes {
        skipWhitespace()
        return consume(until: .lessThan)
    }
    
    mutating func extractAttributes() throws -> (attributes: [(name: Bytes, value: Bytes)], selfClosing: Bool) {
        var attributes: [(Bytes, Bytes)] = []
        
        while let byte = scanner.peek(), byte != .greaterThan, byte != .forwardSlash {
            skipWhitespace()
            
            guard scanner.peek() != .greaterThan else {
                continue
            }
            
            let name = consume(until: attributeTerminators)
            let value = try extractAttributeValue()
            attributes.append((name, value))
        }
        
        assert(scanner.peek() == .greaterThan || scanner.peek() == .forwardSlash)
        let popCount = scanner.peek() == .forwardSlash ? 2 : 1
        scanner.pop(popCount)
        
        return (attributes, popCount == 2)
    }
    
    mutating func extractAttributeValue() throws -> Bytes {
        skip(until: .quote)
        assert(scanner.peek() == .quote)
        
        // opening `"`
        scanner.pop()
        skipWhitespace()
        
        let value = consume(until: .quote)
        
        guard scanner.peek() == .quote else {
            throw Error.malformedXML("expected closing `\"`")
        }
        
        // closing `"`
        scanner.pop()
        return value
    }
}

extension XMLParser {
    mutating func isClosingTag(_ expectedTagName: Bytes) -> Bool {
        assert(scanner.peek(aheadBy: 1) == .forwardSlash)
        
        // </
        scanner.pop(2)
        
        let tagName = consume(until: tagNameTerminators)
        skipWhitespace()
        assert(scanner.peek() == .greaterThan)
        scanner.pop()
        return tagName.elementsEqual(expectedTagName)
    }
    
    mutating func eatComment() {
        assert(scanner.peek() == .exclamationPoint)
        
        //TODO(Brett): be sure this is actually a comment before popping.
        // otherwise throw an error
        // !--
        scanner.pop(3)
        
        while scanner.peek() != nil {
            skip(until: .hyphen)
            
            guard scanner.peek(aheadBy: 1) != .hyphen else {
                // -->
                scanner.pop(3)
                break
            }
        }
    }
}

extension XMLParser {
    mutating func skip(until terminator: Byte) {
        while let byte = scanner.peek(), byte != terminator {
            scanner.pop()
        }
    }
    
    mutating func skip(until terminators: Set<Byte>) {
        while let byte = scanner.peek(), !terminators.contains(byte) {
            scanner.pop()
        }
    }
    
    mutating func skip(while allowed: Set<Byte>) {
        while let byte = scanner.peek(), allowed.contains(byte) {
            scanner.pop()
        }
    }
    mutating func skip(while closure: (Byte) -> Bool) {
        while let byte = scanner.peek(), closure(byte) {
            scanner.pop()
        }
    }
    
    mutating func skipWhitespace() {
        skip(while: whitespace)
    }
    
    mutating func consume(while closure: (Byte) -> Bool) -> Bytes {
        var consumed: [Byte] = []
        
        while let byte = scanner.peek(), closure(byte) {
            consumed.append(byte)
            scanner.pop()
        }
        
        return consumed
    }
    
    mutating func consume(until terminator: Byte) -> Bytes {
        var consumed: [Byte] = []
        
        while let byte = scanner.peek(), byte != terminator {
            consumed.append(byte)
            scanner.pop()
        }
        
        return consumed
    }
    
    mutating func consume(until terminators: Set<Byte>) -> Bytes {
        var consumed: [Byte] = []
        
        while let byte = scanner.peek(), !terminators.contains(byte) {
            consumed.append(byte)
            scanner.pop()
        }
        
        return consumed
    }
}
