// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class CreateTagMutation: GraphQLMutation {
  public static let operationName: String = "CreateTag"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"mutation CreateTag($input: TagInput!) { createTag(input: $input) { __typename id name emoji color tagDescription categoryId } }"#
    ))

  public var input: TagInput

  public init(input: TagInput) {
    self.input = input
  }

  public var __variables: Variables? { ["input": input] }

  public struct Data: JourniaryAPI.SelectionSet {
    public let __data: DataDict
    public init(_dataDict: DataDict) { __data = _dataDict }

    public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.Mutation }
    public static var __selections: [ApolloAPI.Selection] { [
      .field("createTag", CreateTag.self, arguments: ["input": .variable("input")]),
    ] }

    public var createTag: CreateTag { __data["createTag"] }

    /// CreateTag
    ///
    /// Parent Type: `Tag`
    public struct CreateTag: JourniaryAPI.SelectionSet {
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
