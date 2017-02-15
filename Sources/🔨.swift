import Core

extension Sequence where Iterator.Element == Byte {
    public var fasterString: String {
        let count = self.array.count
        
        let ptr = UnsafeMutablePointer<Int8>.allocate(capacity: count + 1)
        ptr.initialize(to: 0, count: count + 1)
        defer {
            ptr.deinitialize()
            ptr.deallocate(capacity: count + 1)
        }
        
        ptr.withMemoryRebound(to: UInt8.self, capacity: count) { reboundPtr in
            self.array.withUnsafeBufferPointer { valuePtr in
                reboundPtr.assign(from: valuePtr.baseAddress!, count: count)
            }
        }
        
        // consider a better way of handling an invalid string
        return String(validatingUTF8: ptr) ?? ""
    }
}
