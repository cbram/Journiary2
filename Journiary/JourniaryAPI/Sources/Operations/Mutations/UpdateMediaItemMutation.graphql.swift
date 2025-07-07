// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class UpdateMediaItemMutation: GraphQLMutation {
  public static let operationName: String = "UpdateMediaItem"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"mutation UpdateMediaItem($id: String!, $input: UpdateMediaItemInput!) { updateMediaItem(id: $id, input: $input) { __typename id s3Key thumbnailS3Key mimeType timestamp order fileSize duration createdAt updatedAt } }"#
    ))

  public var id: String
  public var input: UpdateMediaItemInput

  public init(
    id: String,
    input: UpdateMediaItemInput
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
      .field("updateMediaItem", UpdateMediaItem.self, arguments: [
        "id": .variable("id"),
        "input": .variable("input")
      ]),
    ] }

    /// Update a media item
    public var updateMediaItem: UpdateMediaItem { __data["updateMediaItem"] }

    /// UpdateMediaItem
    ///
    /// Parent Type: `MediaItem`
    public struct UpdateMediaItem: JourniaryAPI.SelectionSet {
      public let __data: DataDict
      public init(_dataDict: DataDict) { __data = _dataDict }

      public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.MediaItem }
      public static var __selections: [ApolloAPI.Selection] { [
        .field("__typename", String.self),
        .field("id", JourniaryAPI.ID.self),
        .field("s3Key", String.self),
        .field("thumbnailS3Key", String?.self),
        .field("mimeType", String.self),
        .field("timestamp", JourniaryAPI.DateTime.self),
        .field("order", Int.self),
        .field("fileSize", Int.self),
        .field("duration", Double?.self),
        .field("createdAt", JourniaryAPI.DateTime.self),
        .field("updatedAt", JourniaryAPI.DateTime.self),
      ] }

      public var id: JourniaryAPI.ID { __data["id"] }
      public var s3Key: String { __data["s3Key"] }
      /// The name of the thumbnail object in the storage (e.g., MinIO)
      public var thumbnailS3Key: String? { __data["thumbnailS3Key"] }
      public var mimeType: String { __data["mimeType"] }
      public var timestamp: JourniaryAPI.DateTime { __data["timestamp"] }
      /// The order of this item within the memory's media list
      public var order: Int { __data["order"] }
      public var fileSize: Int { __data["fileSize"] }
      /// For videos, the duration in seconds.
      public var duration: Double? { __data["duration"] }
      public var createdAt: JourniaryAPI.DateTime { __data["createdAt"] }
      public var updatedAt: JourniaryAPI.DateTime { __data["updatedAt"] }
    }
  }
}
