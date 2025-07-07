// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

/// Update tag data
public struct UpdateTagInput: InputObject {
  public private(set) var __data: InputDict

  public init(_ data: InputDict) {
    __data = data
  }

  public init(
    name: GraphQLNullable<String> = nil,
    color: GraphQLNullable<String> = nil,
    categoryId: GraphQLNullable<ID> = nil
  ) {
    __data = InputDict([
      "name": name,
      "color": color,
      "categoryId": categoryId
    ])
  }

  public var name: GraphQLNullable<String> {
    get { __data["name"] }
    set { __data["name"] = newValue }
  }

  public var color: GraphQLNullable<String> {
    get { __data["color"] }
    set { __data["color"] = newValue }
  }

  public var categoryId: GraphQLNullable<ID> {
    get { __data["categoryId"] }
    set { __data["categoryId"] = newValue }
  }
}
