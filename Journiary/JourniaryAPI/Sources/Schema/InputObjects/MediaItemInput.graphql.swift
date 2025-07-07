// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

/// Input data for creating a new MediaItem
public struct MediaItemInput: InputObject {
  public private(set) var __data: InputDict

  public init(_ data: InputDict) {
    __data = data
  }

  public init(
    objectName: String,
    thumbnailObjectName: GraphQLNullable<String> = nil,
    memoryId: String,
    mediaType: String,
    timestamp: DateTime,
    order: Int,
    filesize: Int,
    duration: GraphQLNullable<Int> = nil
  ) {
    __data = InputDict([
      "objectName": objectName,
      "thumbnailObjectName": thumbnailObjectName,
      "memoryId": memoryId,
      "mediaType": mediaType,
      "timestamp": timestamp,
      "order": order,
      "filesize": filesize,
      "duration": duration
    ])
  }

  /// The name of the object in the storage (e.g., from createUploadUrl)
  public var objectName: String {
    get { __data["objectName"] }
    set { __data["objectName"] = newValue }
  }

  /// The name of the thumbnail object in the storage
  public var thumbnailObjectName: GraphQLNullable<String> {
    get { __data["thumbnailObjectName"] }
    set { __data["thumbnailObjectName"] = newValue }
  }

  /// The ID of the memory this media item belongs to
  public var memoryId: String {
    get { __data["memoryId"] }
    set { __data["memoryId"] = newValue }
  }

  /// The type of media, e.g., 'image', 'video'.
  public var mediaType: String {
    get { __data["mediaType"] }
    set { __data["mediaType"] = newValue }
  }

  /// The timestamp of when the media was created
  public var timestamp: DateTime {
    get { __data["timestamp"] }
    set { __data["timestamp"] = newValue }
  }

  /// The order of this item within the memory's media list
  public var order: Int {
    get { __data["order"] }
    set { __data["order"] = newValue }
  }

  /// File size in bytes
  public var filesize: Int {
    get { __data["filesize"] }
    set { __data["filesize"] = newValue }
  }

  /// For videos, the duration in seconds.
  public var duration: GraphQLNullable<Int> {
    get { __data["duration"] }
    set { __data["duration"] = newValue }
  }
}
