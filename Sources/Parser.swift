import Core
import Node

/// \n, \t, ' ' or \r
let whitespace: Set<Byte> = [.newLine, .horizontalTab, .space, .carriageReturn]

///  =, \n, \t, ' ' or \r
let attributeTerminators = whitespace.union([.equals])

///  ", \n, \t, ' ' or \r
let attributeValueTerminators = whitespace.union([.quote])

///  >, /, \n, \t, ' ' or \r
let tagNameTerminators = whitespace.union([.greaterThan, .forwardSlash])

/// <![CDATA[
let cDataHeader: Bytes = [.lessThan, .exclamationPoint, .leftSquareBracket, .C, .D, .A, .T, .A, .leftSquareBracket]

/// ]]>
let cDataFooter: Bytes = [.rightSquareBracket, .rightSquareBracket, .greaterThan]

/// !--
let commentHeader: Bytes = [.exclamationPoint, .hyphen, .hyphen]

/// -->
let commentFooter: Bytes = [.hyphen, .hyphen, .greaterThan]

/// </
let closingTagHeader: Bytes = [.lessThan, .forwardSlash]

/// />
let selfClosingTagFooter: Bytes = [.forwardSlash, .greaterThan]

extension Byte {
    /// <
    public static let lessThan: Byte = 0x3C
    
    /// >
    public static let greaterThan: Byte = 0x3E
    
    /// !
    public static let exclamationPoint: Byte = 0x21
    
    /// T
    public static let T: Byte = 0x54
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
    public static func parse(_ xml: String) throws -> BML {
        return try parse(xml.bytes)
    }
    
    public static func parse(_ bytes: Bytes) throws -> BML {
        var parser = XMLParser(scanner: Scanner(bytes))
        
        parser.trimByteOrderMark()
        
        guard let root = try parser.extractTag() else {
           throw Error.malformedXML("Expected root element.")
        }

        return root
    }
    
    mutating func trimByteOrderMark() {
        if
            scanner.peek() == 0xEF,
            scanner.peek(aheadBy: 1) == 0xBB,
            scanner.peek(aheadBy: 2) == 0xBF
        {
            scanner.pop(3)
        }
    }
}

extension XMLParser {
    //TODO(Brett): merge this functionality with extractObject
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
            try eatComment()
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
    
    mutating func extractObject() throws -> BML {
        // TODO(Brett):
        // I shouldn't have to do this, figure out which state is throwing
        // the pointer into a garbage state
        if scanner.peek() == .lessThan {
            scanner.pop()
        }
        
        let name = consume(until: tagNameTerminators)
        
        let sighting = BML(name: name)

        sighting.attributes = try extractAttributes()
        
        skipWhitespace()
        
        guard let token = scanner.peek() else {
            throw Error.unexpectedEndOfFile
        }
        
        // self-closing tag early-escape
        guard token != .forwardSlash else {
            try expect(selfClosingTagFooter)
            return sighting
        }
        
        guard token == .greaterThan else {
            throw Error.malformedXML("Expected `>` for tag: \(name.makeString())")
        }
        
        // >
        scanner.pop()
        
        outerLoop: while scanner.peek() != nil {
            skipWhitespace()

            guard let byte = scanner.peek() else {
                continue
            }

            switch byte {
            case Byte.lessThan:
                // closing tag
                
                switch scanner.peek(aheadBy: 1) {
                case Byte.forwardSlash?:
                    if try isClosingTag(name) {
                        break outerLoop
                    } else {
                        throw Error.malformedXML("Expected closing tag </\(name.fasterString)>")
                    }
                    
                case Byte.exclamationPoint?:
                    switch scanner.peek(aheadBy: 2) {
                    case Byte.hyphen?:
                        try eatComment()
                        
                    case Byte.leftSquareBracket?:
                        sighting._value = try extractCData()
                        
                    default:
                        throw Error.malformedXML("Expected comment or CDATA near ! in tag \(name.fasterString)")
                    }
                    
                default:
                    let subObject = try extractObject()
                    sighting.add(child: subObject)
                }
                
            default:
                sighting._value = extractTagText()
            }
        }
        
        return sighting
    }
    
    mutating func extractTagText() -> Bytes {
        skipWhitespace()
        return consume(until: .lessThan)
    }
    
    mutating func extractCData() throws -> Bytes {
        try expect(cDataHeader)
        
        var cdata: [Byte] = []
        
        while let byte = scanner.peek() {
            if byte == .rightSquareBracket {
                if find(cDataFooter) {
                    // consume footer
                    try expect(cDataFooter)
                    break
                }
            }
            
            scanner.pop()
            cdata.append(byte)
        }
        
        return cdata
    }
    
    mutating func extractAttributes() throws -> [BML] {
        var attributes: [BML] = []
        
        while let byte = scanner.peek(), byte != .greaterThan, byte != .forwardSlash {
            skipWhitespace()
            
            guard scanner.peek() != .greaterThan, scanner.peek() != .forwardSlash else {
                continue
            }
            
            let name = consume(until: attributeTerminators)
            let value = try extractAttributeValue()
            attributes.append(BML(name: name, value: value))
        }
        
        return attributes
    }
    
    mutating func extractAttributeValue() throws -> Bytes {
        skip(until: .quote)
        
        try expect([.quote])
        skipWhitespace()
        
        let value = consume(until: .quote)
        
        try expect([.quote])
        
        return value
    }
}

extension XMLParser {
    mutating func isClosingTag(_ expectedTagName: Bytes) throws -> Bool {
        try expect(closingTagHeader)
        
        let tagName = consume(until: tagNameTerminators)
        
        skipWhitespace()
        try expect([.greaterThan])
        
        return tagName.elementsEqual(expectedTagName)
    }
    
    mutating func eatComment() throws {
        try expect(commentHeader)
        
        while scanner.peek() != nil {
            skip(until: .hyphen)
            
            guard !find(commentFooter) else {
                // consume
                try expect(commentFooter)
                break
            }
        }
    }
}

extension XMLParser {
    mutating func find(_ bytes: Bytes, startingFrom start: Int = 0) -> Bool {
        var peeked = start
        
        for expect in bytes {
            guard scanner.peek(aheadBy: peeked) == expect else {
                return false
            }
            
            peeked += 1
        }
        
        return true
    }
    
    mutating func expect(_ bytes: Bytes) throws {
        for expected in bytes {
            guard scanner.peek() == expected else {
                throw Error.malformedXML("Expected \(bytes.fasterString)")
            }
            
            scanner.pop()
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
