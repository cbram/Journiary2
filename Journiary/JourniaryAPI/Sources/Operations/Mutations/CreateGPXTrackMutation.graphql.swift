// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class CreateGPXTrackMutation: GraphQLMutation {
  public static let operationName: String = "CreateGPXTrack"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"mutation CreateGPXTrack($input: GPXTrackInput!) { createGpxTrack(input: $input) { __typename id updatedAt } }"#
    ))

  public var input: GPXTrackInput

  public init(input: GPXTrackInput) {
    self.input = input
  }

  public var __variables: Variables? { ["input": input] }

  public struct Data: JourniaryAPI.SelectionSet {
    public let __data: DataDict
    public init(_dataDict: DataDict) { __data = _dataDict }

    public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.Mutation }
    public static var __selections: [ApolloAPI.Selection] { [
      .field("createGpxTrack", CreateGpxTrack.self, arguments: ["input": .variable("input")]),
    ] }

    /// Creates a new GPX track record and processes the uploaded file.
    public var createGpxTrack: CreateGpxTrack { __data["createGpxTrack"] }

    /// CreateGpxTrack
    ///
    /// Parent Type: `GPXTrack`
    public struct CreateGpxTrack: JourniaryAPI.SelectionSet {
      public let __data: DataDict
      public init(_dataDict: DataDict) { __data = _dataDict }

      public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.GPXTrack }
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
