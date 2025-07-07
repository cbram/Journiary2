// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

/// Input data for creating a new GPXTrack
public struct GPXTrackInput: InputObject {
  public private(set) var __data: InputDict

  public init(_ data: InputDict) {
    __data = data
  }

  public init(
    name: String,
    gpxFileObjectName: GraphQLNullable<String> = nil,
    originalFilename: GraphQLNullable<String> = nil,
    tripId: ID,
    memoryId: GraphQLNullable<ID> = nil,
    creator: GraphQLNullable<String> = nil,
    trackType: GraphQLNullable<String> = nil
  ) {
    __data = InputDict([
      "name": name,
      "gpxFileObjectName": gpxFileObjectName,
      "originalFilename": originalFilename,
      "tripId": tripId,
      "memoryId": memoryId,
      "creator": creator,
      "trackType": trackType
    ])
  }

  /// The name of the GPX track
  public var name: String {
    get { __data["name"] }
    set { __data["name"] = newValue }
  }

  /// The name of the uploaded GPX file in the object storage
  public var gpxFileObjectName: GraphQLNullable<String> {
    get { __data["gpxFileObjectName"] }
    set { __data["gpxFileObjectName"] = newValue }
  }

  public var originalFilename: GraphQLNullable<String> {
    get { __data["originalFilename"] }
    set { __data["originalFilename"] = newValue }
  }

  /// The ID of the trip this GPX track belongs to
  public var tripId: ID {
    get { __data["tripId"] }
    set { __data["tripId"] = newValue }
  }

  /// Optional ID of the memory this GPX track is associated with
  public var memoryId: GraphQLNullable<ID> {
    get { __data["memoryId"] }
    set { __data["memoryId"] = newValue }
  }

  public var creator: GraphQLNullable<String> {
    get { __data["creator"] }
    set { __data["creator"] = newValue }
  }

  public var trackType: GraphQLNullable<String> {
    get { __data["trackType"] }
    set { __data["trackType"] = newValue }
  }
}
