// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

/// Input data for creating a new Tag Category
public struct TagCategoryInput: InputObject {
  public private(set) var __data: InputDict

  public init(_ data: InputDict) {
    __data = data
  }

  public init(
    name: String,
    emoji: GraphQLNullable<String> = nil,
    color: GraphQLNullable<String> = nil
  ) {
    __data = InputDict([
      "name": name,
      "emoji": emoji,
      "color": color
    ])
  }

  public var name: String {
    get { __data["name"] }
    set { __data["name"] = newValue }
  }

  public var emoji: GraphQLNullable<String> {
    get { __data["emoji"] }
    set { __data["emoji"] = newValue }
  }

  public var color: GraphQLNullable<String> {
    get { __data["color"] }
    set { __data["color"] = newValue }
  }
}
