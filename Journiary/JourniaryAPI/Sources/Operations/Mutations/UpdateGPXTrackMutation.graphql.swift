// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class UpdateGPXTrackMutation: GraphQLMutation {
  public static let operationName: String = "UpdateGPXTrack"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"mutation UpdateGPXTrack($id: ID!, $input: UpdateGPXTrackInput!) { updateGpxTrack(id: $id, input: $input) { __typename id name gpxFileObjectName originalFilename creator trackType totalDistance elevationGain elevationLoss minElevation maxElevation createdAt updatedAt } }"#
    ))

  public var id: ID
  public var input: UpdateGPXTrackInput

  public init(
    id: ID,
    input: UpdateGPXTrackInput
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
      .field("updateGpxTrack", UpdateGpxTrack.self, arguments: [
        "id": .variable("id"),
        "input": .variable("input")
      ]),
    ] }

    /// Update a GPX track
    public var updateGpxTrack: UpdateGpxTrack { __data["updateGpxTrack"] }

    /// UpdateGpxTrack
    ///
    /// Parent Type: `GPXTrack`
    public struct UpdateGpxTrack: JourniaryAPI.SelectionSet {
      public let __data: DataDict
      public init(_dataDict: DataDict) { __data = _dataDict }

      public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.GPXTrack }
      public static var __selections: [ApolloAPI.Selection] { [
        .field("__typename", String.self),
        .field("id", JourniaryAPI.ID.self),
        .field("name", String.self),
        .field("gpxFileObjectName", String?.self),
        .field("originalFilename", String?.self),
        .field("creator", String?.self),
        .field("trackType", String?.self),
        .field("totalDistance", Double?.self),
        .field("elevationGain", Double?.self),
        .field("elevationLoss", Double?.self),
        .field("minElevation", Double?.self),
        .field("maxElevation", Double?.self),
        .field("createdAt", JourniaryAPI.DateTime.self),
        .field("updatedAt", JourniaryAPI.DateTime.self),
      ] }

      public var id: JourniaryAPI.ID { __data["id"] }
      public var name: String { __data["name"] }
      /// The name of the GPX file object in the storage (e.g., MinIO)
      public var gpxFileObjectName: String? { __data["gpxFileObjectName"] }
      public var originalFilename: String? { __data["originalFilename"] }
      public var creator: String? { __data["creator"] }
      public var trackType: String? { __data["trackType"] }
      public var totalDistance: Double? { __data["totalDistance"] }
      public var elevationGain: Double? { __data["elevationGain"] }
      public var elevationLoss: Double? { __data["elevationLoss"] }
      public var minElevation: Double? { __data["minElevation"] }
      public var maxElevation: Double? { __data["maxElevation"] }
      public var createdAt: JourniaryAPI.DateTime { __data["createdAt"] }
      public var updatedAt: JourniaryAPI.DateTime { __data["updatedAt"] }
    }
  }
}
