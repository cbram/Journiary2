// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class UpdateTripMutation: GraphQLMutation {
  public static let operationName: String = "UpdateTrip"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"mutation UpdateTrip($id: ID!, $input: UpdateTripInput!) { updateTrip(id: $id, input: $input) { __typename id name tripDescription startDate endDate updatedAt } }"#
    ))

  public var id: ID
  public var input: UpdateTripInput

  public init(
    id: ID,
    input: UpdateTripInput
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
      .field("updateTrip", UpdateTrip.self, arguments: [
        "id": .variable("id"),
        "input": .variable("input")
      ]),
    ] }

    /// Update an existing trip
    public var updateTrip: UpdateTrip { __data["updateTrip"] }

    /// UpdateTrip
    ///
    /// Parent Type: `Trip`
    public struct UpdateTrip: JourniaryAPI.SelectionSet {
      public let __data: DataDict
      public init(_dataDict: DataDict) { __data = _dataDict }

      public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.Trip }
      public static var __selections: [ApolloAPI.Selection] { [
        .field("__typename", String.self),
        .field("id", JourniaryAPI.ID.self),
        .field("name", String.self),
        .field("tripDescription", String?.self),
        .field("startDate", JourniaryAPI.DateTime.self),
        .field("endDate", JourniaryAPI.DateTime?.self),
        .field("updatedAt", JourniaryAPI.DateTime.self),
      ] }

      public var id: JourniaryAPI.ID { __data["id"] }
      public var name: String { __data["name"] }
      public var tripDescription: String? { __data["tripDescription"] }
      public var startDate: JourniaryAPI.DateTime { __data["startDate"] }
      public var endDate: JourniaryAPI.DateTime? { __data["endDate"] }
      public var updatedAt: JourniaryAPI.DateTime { __data["updatedAt"] }
    }
  }
}
