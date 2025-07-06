// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class DeleteTripMutation: GraphQLMutation {
  public static let operationName: String = "DeleteTrip"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"mutation DeleteTrip($id: ID!) { deleteTrip(id: $id) }"#
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
      .field("deleteTrip", Bool.self, arguments: ["id": .variable("id")]),
    ] }

    /// Delete a trip
    public var deleteTrip: Bool { __data["deleteTrip"] }
  }
}
