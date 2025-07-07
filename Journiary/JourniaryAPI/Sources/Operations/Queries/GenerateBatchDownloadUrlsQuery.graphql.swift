// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class GenerateBatchDownloadUrlsQuery: GraphQLQuery {
  public static let operationName: String = "GenerateBatchDownloadUrls"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"query GenerateBatchDownloadUrls($mediaItemIds: [ID!], $gpxTrackIds: [ID!], $expiresIn: Int) { generateBatchDownloadUrls( mediaItemIds: $mediaItemIds gpxTrackIds: $gpxTrackIds expiresIn: $expiresIn ) { __typename downloadUrls { __typename entityId entityType objectName downloadUrl expiresIn } generatedAt } }"#
    ))

  public var mediaItemIds: GraphQLNullable<[ID]>
  public var gpxTrackIds: GraphQLNullable<[ID]>
  public var expiresIn: GraphQLNullable<Int>

  public init(
    mediaItemIds: GraphQLNullable<[ID]>,
    gpxTrackIds: GraphQLNullable<[ID]>,
    expiresIn: GraphQLNullable<Int>
  ) {
    self.mediaItemIds = mediaItemIds
    self.gpxTrackIds = gpxTrackIds
    self.expiresIn = expiresIn
  }

  public var __variables: Variables? { [
    "mediaItemIds": mediaItemIds,
    "gpxTrackIds": gpxTrackIds,
    "expiresIn": expiresIn
  ] }

  public struct Data: JourniaryAPI.SelectionSet {
    public let __data: DataDict
    public init(_dataDict: DataDict) { __data = _dataDict }

    public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.Query }
    public static var __selections: [ApolloAPI.Selection] { [
      .field("generateBatchDownloadUrls", GenerateBatchDownloadUrls.self, arguments: [
        "mediaItemIds": .variable("mediaItemIds"),
        "gpxTrackIds": .variable("gpxTrackIds"),
        "expiresIn": .variable("expiresIn")
      ]),
    ] }

    /// Generate batch download URLs for media files and GPX tracks
    public var generateBatchDownloadUrls: GenerateBatchDownloadUrls { __data["generateBatchDownloadUrls"] }

    /// GenerateBatchDownloadUrls
    ///
    /// Parent Type: `FileSyncResponse`
    public struct GenerateBatchDownloadUrls: JourniaryAPI.SelectionSet {
      public let __data: DataDict
      public init(_dataDict: DataDict) { __data = _dataDict }

      public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.FileSyncResponse }
      public static var __selections: [ApolloAPI.Selection] { [
        .field("__typename", String.self),
        .field("downloadUrls", [DownloadUrl].self),
        .field("generatedAt", JourniaryAPI.DateTime.self),
      ] }

      public var downloadUrls: [DownloadUrl] { __data["downloadUrls"] }
      public var generatedAt: JourniaryAPI.DateTime { __data["generatedAt"] }

      /// GenerateBatchDownloadUrls.DownloadUrl
      ///
      /// Parent Type: `FileDownloadUrl`
      public struct DownloadUrl: JourniaryAPI.SelectionSet {
        public let __data: DataDict
        public init(_dataDict: DataDict) { __data = _dataDict }

        public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.FileDownloadUrl }
        public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("entityId", JourniaryAPI.ID.self),
          .field("entityType", String.self),
          .field("objectName", String.self),
          .field("downloadUrl", String.self),
          .field("expiresIn", Int.self),
        ] }

        public var entityId: JourniaryAPI.ID { __data["entityId"] }
        public var entityType: String { __data["entityType"] }
        public var objectName: String { __data["objectName"] }
        public var downloadUrl: String { __data["downloadUrl"] }
        public var expiresIn: Int { __data["expiresIn"] }
      }
    }
  }
}
