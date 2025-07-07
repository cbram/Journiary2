// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class GenerateBatchUploadUrlsMutation: GraphQLMutation {
  public static let operationName: String = "GenerateBatchUploadUrls"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"mutation GenerateBatchUploadUrls($uploadRequests: [UploadRequest!]!, $expiresIn: Int) { generateBatchUploadUrls(uploadRequests: $uploadRequests, expiresIn: $expiresIn) { __typename uploadUrls { __typename entityId entityType objectName uploadUrl expiresIn } generatedAt } }"#
    ))

  public var uploadRequests: [UploadRequest]
  public var expiresIn: GraphQLNullable<Int>

  public init(
    uploadRequests: [UploadRequest],
    expiresIn: GraphQLNullable<Int>
  ) {
    self.uploadRequests = uploadRequests
    self.expiresIn = expiresIn
  }

  public var __variables: Variables? { [
    "uploadRequests": uploadRequests,
    "expiresIn": expiresIn
  ] }

  public struct Data: JourniaryAPI.SelectionSet {
    public let __data: DataDict
    public init(_dataDict: DataDict) { __data = _dataDict }

    public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.Mutation }
    public static var __selections: [ApolloAPI.Selection] { [
      .field("generateBatchUploadUrls", GenerateBatchUploadUrls.self, arguments: [
        "uploadRequests": .variable("uploadRequests"),
        "expiresIn": .variable("expiresIn")
      ]),
    ] }

    /// Generate batch upload URLs for media files and GPX tracks
    public var generateBatchUploadUrls: GenerateBatchUploadUrls { __data["generateBatchUploadUrls"] }

    /// GenerateBatchUploadUrls
    ///
    /// Parent Type: `BulkUploadResponse`
    public struct GenerateBatchUploadUrls: JourniaryAPI.SelectionSet {
      public let __data: DataDict
      public init(_dataDict: DataDict) { __data = _dataDict }

      public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.BulkUploadResponse }
      public static var __selections: [ApolloAPI.Selection] { [
        .field("__typename", String.self),
        .field("uploadUrls", [UploadUrl].self),
        .field("generatedAt", JourniaryAPI.DateTime.self),
      ] }

      public var uploadUrls: [UploadUrl] { __data["uploadUrls"] }
      public var generatedAt: JourniaryAPI.DateTime { __data["generatedAt"] }

      /// GenerateBatchUploadUrls.UploadUrl
      ///
      /// Parent Type: `BulkUploadUrl`
      public struct UploadUrl: JourniaryAPI.SelectionSet {
        public let __data: DataDict
        public init(_dataDict: DataDict) { __data = _dataDict }

        public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.BulkUploadUrl }
        public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("entityId", JourniaryAPI.ID.self),
          .field("entityType", String.self),
          .field("objectName", String.self),
          .field("uploadUrl", String.self),
          .field("expiresIn", Int.self),
        ] }

        public var entityId: JourniaryAPI.ID { __data["entityId"] }
        public var entityType: String { __data["entityType"] }
        public var objectName: String { __data["objectName"] }
        public var uploadUrl: String { __data["uploadUrl"] }
        public var expiresIn: Int { __data["expiresIn"] }
      }
    }
  }
}
