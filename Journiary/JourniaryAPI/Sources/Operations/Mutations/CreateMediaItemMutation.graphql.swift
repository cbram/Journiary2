// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class CreateMediaItemMutation: GraphQLMutation {
  public static let operationName: String = "CreateMediaItem"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"mutation CreateMediaItem($input: MediaItemInput!) { createMediaItem(input: $input) { __typename id updatedAt } }"#
    ))

  public var input: MediaItemInput

  public init(input: MediaItemInput) {
    self.input = input
  }

  public var __variables: Variables? { ["input": input] }

  public struct Data: JourniaryAPI.SelectionSet {
    public let __data: DataDict
    public init(_dataDict: DataDict) { __data = _dataDict }

    public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.Mutation }
    public static var __selections: [ApolloAPI.Selection] { [
      .field("createMediaItem", CreateMediaItem.self, arguments: ["input": .variable("input")]),
    ] }

    public var createMediaItem: CreateMediaItem { __data["createMediaItem"] }

    /// CreateMediaItem
    ///
    /// Parent Type: `MediaItem`
    public struct CreateMediaItem: JourniaryAPI.SelectionSet {
      public let __data: DataDict
      public init(_dataDict: DataDict) { __data = _dataDict }

      public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.MediaItem }
      public static var __selections: [ApolloAPI.Selection] { [
        .field("__typename", String.self),
        .field("id", JourniaryAPI.ID.self),
        .field("updatedAt", JourniaryAPI.DateTime.self),
      ] }

      public var id: JourniaryAPI.ID { __data["id"] }
      public var updatedAt: JourniaryAPI.DateTime { __data["updatedAt"] }
    }
  }
}
