// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

/// Update tag category data
public struct UpdateTagCategoryInput: InputObject {
  public private(set) var __data: InputDict

  public init(_ data: InputDict) {
    __data = data
  }

  public init(
    name: GraphQLNullable<String> = nil,
    color: GraphQLNullable<String> = nil,
    icon: GraphQLNullable<String> = nil
  ) {
    __data = InputDict([
      "name": name,
      "color": color,
      "icon": icon
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

  public var icon: GraphQLNullable<String> {
    get { __data["icon"] }
    set { __data["icon"] = newValue }
  }
}
