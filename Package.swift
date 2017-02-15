import PackageDescription

let package = Package(
    name: "BML",
    dependencies: [
        .Package(url: "https://github.com/vapor/core.git", majorVersion: 1),
        .Package(url: "https://github.com/vapor/node.git", majorVersion: 1)
    ]
)
