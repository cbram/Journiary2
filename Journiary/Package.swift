// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "JourniaryGraphQL",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "JourniaryGraphQL",
            targets: ["JourniaryGraphQL"]
        ),
    ],
    dependencies: [
        // Apollo iOS für GraphQL Client
        .package(url: "https://github.com/apollographql/apollo-ios.git", from: "1.9.0"),
    ],
    targets: [
        .target(
            name: "JourniaryGraphQL",
            dependencies: [
                .product(name: "Apollo", package: "apollo-ios"),
                .product(name: "ApolloSQLite", package: "apollo-ios"),
                .product(name: "ApolloAPI", package: "apollo-ios"),
            ]
        ),
    ]
) 