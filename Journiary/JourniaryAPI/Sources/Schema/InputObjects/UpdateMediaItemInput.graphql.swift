// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

/// Input data for updating a MediaItem
public struct UpdateMediaItemInput: InputObject {
  public private(set) var __data: InputDict

  public init(_ data: InputDict) {
    __data = data
  }

  public init(
    objectName: GraphQLNullable<String> = nil,
    thumbnailObjectName: GraphQLNullable<String> = nil,
    mediaType: GraphQLNullable<String> = nil,
    timestamp: GraphQLNullable<DateTime> = nil,
    order: GraphQLNullable<Int> = nil,
    filesize: GraphQLNullable<Int> = nil,
    duration: GraphQLNullable<Int> = nil
  ) {
    __data = InputDict([
      "objectName": objectName,
      "thumbnailObjectName": thumbnailObjectName,
      "mediaType": mediaType,
      "timestamp": timestamp,
      "order": order,
      "filesize": filesize,
      "duration": duration
    ])
  }

  /// The name of the object in the storage (e.g., from createUploadUrl)
  public var objectName: GraphQLNullable<String> {
    get { __data["objectName"] }
    set { __data["objectName"] = newValue }
  }

  /// The name of the thumbnail object in the storage
  public var thumbnailObjectName: GraphQLNullable<String> {
    get { __data["thumbnailObjectName"] }
    set { __data["thumbnailObjectName"] = newValue }
  }

  /// The type of media, e.g., 'image', 'video'.
  public var mediaType: GraphQLNullable<String> {
    get { __data["mediaType"] }
    set { __data["mediaType"] = newValue }
  }

  /// The timestamp of when the media was created
  public var timestamp: GraphQLNullable<DateTime> {
    get { __data["timestamp"] }
    set { __data["timestamp"] = newValue }
  }

  /// The order of this item within the memory's media list
  public var order: GraphQLNullable<Int> {
    get { __data["order"] }
    set { __data["order"] = newValue }
  }

  /// File size in bytes
  public var filesize: GraphQLNullable<Int> {
    get { __data["filesize"] }
    set { __data["filesize"] = newValue }
  }

  /// For videos, the duration in seconds.
  public var duration: GraphQLNullable<Int> {
    get { __data["duration"] }
    set { __data["duration"] = newValue }
  }
}
