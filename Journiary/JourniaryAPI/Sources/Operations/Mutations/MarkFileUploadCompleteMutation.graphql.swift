// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class MarkFileUploadCompleteMutation: GraphQLMutation {
  public static let operationName: String = "MarkFileUploadComplete"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"mutation MarkFileUploadComplete($entityId: ID!, $entityType: String!, $objectName: String!) { markFileUploadComplete( entityId: $entityId entityType: $entityType objectName: $objectName ) }"#
    ))

  public var entityId: ID
  public var entityType: String
  public var objectName: String

  public init(
    entityId: ID,
    entityType: String,
    objectName: String
  ) {
    self.entityId = entityId
    self.entityType = entityType
    self.objectName = objectName
  }

  public var __variables: Variables? { [
    "entityId": entityId,
    "entityType": entityType,
    "objectName": objectName
  ] }

  public struct Data: JourniaryAPI.SelectionSet {
    public let __data: DataDict
    public init(_dataDict: DataDict) { __data = _dataDict }

    public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.Mutation }
    public static var __selections: [ApolloAPI.Selection] { [
      .field("markFileUploadComplete", Bool.self, arguments: [
        "entityId": .variable("entityId"),
        "entityType": .variable("entityType"),
        "objectName": .variable("objectName")
      ]),
    ] }

    /// Mark file upload as completed and update entity
    public var markFileUploadComplete: Bool { __data["markFileUploadComplete"] }
  }
}
