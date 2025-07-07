// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class UpdateTagCategoryMutation: GraphQLMutation {
  public static let operationName: String = "UpdateTagCategory"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"mutation UpdateTagCategory($id: String!, $input: UpdateTagCategoryInput!) { updateTagCategory(id: $id, input: $input) { __typename id name displayName emoji color isSystemCategory sortOrder isExpanded createdAt updatedAt } }"#
    ))

  public var id: String
  public var input: UpdateTagCategoryInput

  public init(
    id: String,
    input: UpdateTagCategoryInput
  ) {
    self.id = id
    self.input = input
  }

  public var __variables: Variables? { [
    "id": id,
    "input": input
  ] }

  public struct Data: JourniaryAPI.SelectionSet {
    public let __data: DataDict
    public init(_dataDict: DataDict) { __data = _dataDict }

    public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.Mutation }
    public static var __selections: [ApolloAPI.Selection] { [
      .field("updateTagCategory", UpdateTagCategory?.self, arguments: [
        "id": .variable("id"),
        "input": .variable("input")
      ]),
    ] }

    public var updateTagCategory: UpdateTagCategory? { __data["updateTagCategory"] }

    /// UpdateTagCategory
    ///
    /// Parent Type: `TagCategory`
    public struct UpdateTagCategory: JourniaryAPI.SelectionSet {
      public let __data: DataDict
      public init(_dataDict: DataDict) { __data = _dataDict }

      public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.TagCategory }
      public static var __selections: [ApolloAPI.Selection] { [
        .field("__typename", String.self),
        .field("id", JourniaryAPI.ID.self),
        .field("name", String.self),
        .field("displayName", String?.self),
        .field("emoji", String?.self),
        .field("color", String?.self),
        .field("isSystemCategory", Bool.self),
        .field("sortOrder", Int.self),
        .field("isExpanded", Bool.self),
        .field("createdAt", JourniaryAPI.DateTime.self),
        .field("updatedAt", JourniaryAPI.DateTime.self),
      ] }

      public var id: JourniaryAPI.ID { __data["id"] }
      public var name: String { __data["name"] }
      public var displayName: String? { __data["displayName"] }
      public var emoji: String? { __data["emoji"] }
      public var color: String? { __data["color"] }
      public var isSystemCategory: Bool { __data["isSystemCategory"] }
      public var sortOrder: Int { __data["sortOrder"] }
      public var isExpanded: Bool { __data["isExpanded"] }
      public var createdAt: JourniaryAPI.DateTime { __data["createdAt"] }
      public var updatedAt: JourniaryAPI.DateTime { __data["updatedAt"] }
    }
  }
}
