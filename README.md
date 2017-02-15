# Brett XML
[![Language](https://img.shields.io/badge/Swift-3-brightgreen.svg)](http://swift.org) ![Build Status](https://travis-ci.org/BrettRToomey/brett-xml.svg?branch=master)
[![codecov](https://codecov.io/gh/BrettRToomey/brett-xml/branch/master/graph/badge.svg)](https://codecov.io/gh/BrettRToomey/brett-xml)
[![GitHub license](https://img.shields.io/badge/license-MIT-blue.svg)](https://raw.githubusercontent.com/BrettRToomey/brett-xml/master/LICENSE)

A pure Swift XML parser that's compatible with [Vapor's node](http://vapor.codes) data structure.

## Integration
Update your `Package.swift` file.
```swift
.Package(url: "https://github.com/BrettRToomey/brett-xml.git", majorVersion: 0)
```

## Getting started 🚀
BML is easy to use, just pass it a `String` or an array of `Byte`s.
```swift
import BML
let node = try XMLParser.parse("<book id=\"5\"></book>")
print(node["book", "id"]?.int) // prints 5
```