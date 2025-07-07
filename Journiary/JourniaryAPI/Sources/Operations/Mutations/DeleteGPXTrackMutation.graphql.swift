// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class DeleteGPXTrackMutation: GraphQLMutation {
  public static let operationName: String = "DeleteGPXTrack"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"mutation DeleteGPXTrack($id: ID!) { deleteGpxTrack(id: $id) }"#
    ))

  public var id: ID

  public init(id: ID) {
    self.id = id
  }

  public var __variables: Variables? { ["id": id] }

  public struct Data: JourniaryAPI.SelectionSet {
    public let __data: DataDict
    public init(_dataDict: DataDict) { __data = _dataDict }

    public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.Mutation }
    public static var __selections: [ApolloAPI.Selection] { [
      .field("deleteGpxTrack", Bool.self, arguments: ["id": .variable("id")]),
    ] }

    /// Deletes a GPX track and its associated data.
    public var deleteGpxTrack: Bool { __data["deleteGpxTrack"] }
  }
}
