// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class UpdateTagMutation: GraphQLMutation {
  public static let operationName: String = "UpdateTag"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"mutation UpdateTag($id: String!, $input: UpdateTagInput!) { updateTag(id: $id, input: $input) { __typename id name emoji color tagDescription categoryId } }"#
    ))

  public var id: String
  public var input: UpdateTagInput

  public init(
    id: String,
    input: UpdateTagInput
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
      .field("updateTag", UpdateTag?.self, arguments: [
        "id": .variable("id"),
        "input": .variable("input")
      ]),
    ] }

    public var updateTag: UpdateTag? { __data["updateTag"] }

    /// UpdateTag
    ///
    /// Parent Type: `Tag`
    public struct UpdateTag: JourniaryAPI.SelectionSet {
      public let __data: DataDict
      public init(_dataDict: DataDict) { __data = _dataDict }

      public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.Tag }
      public static var __selections: [ApolloAPI.Selection] { [
        .field("__typename", String.self),
        .field("id", JourniaryAPI.ID.self),
        .field("name", String.self),
        .field("emoji", String?.self),
        .field("color", String?.self),
        .field("tagDescription", String?.self),
        .field("categoryId", String?.self),
      ] }

      public var id: JourniaryAPI.ID { __data["id"] }
      public var name: String { __data["name"] }
      public var emoji: String? { __data["emoji"] }
      public var color: String? { __data["color"] }
      public var tagDescription: String? { __data["tagDescription"] }
      public var categoryId: String? { __data["categoryId"] }
    }
  }
}
