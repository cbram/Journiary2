// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public struct UploadRequest: InputObject {
  public private(set) var __data: InputDict

  public init(_ data: InputDict) {
    __data = data
  }

  public init(
    entityId: ID,
    entityType: String,
    objectName: String,
    mimeType: String
  ) {
    __data = InputDict([
      "entityId": entityId,
      "entityType": entityType,
      "objectName": objectName,
      "mimeType": mimeType
    ])
  }

  public var entityId: ID {
    get { __data["entityId"] }
    set { __data["entityId"] = newValue }
  }

  public var entityType: String {
    get { __data["entityType"] }
    set { __data["entityType"] = newValue }
  }

  public var objectName: String {
    get { __data["objectName"] }
    set { __data["objectName"] = newValue }
  }

  public var mimeType: String {
    get { __data["mimeType"] }
    set { __data["mimeType"] = newValue }
  }
}
