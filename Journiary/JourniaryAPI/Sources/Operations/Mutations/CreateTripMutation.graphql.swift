// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class CreateTripMutation: GraphQLMutation {
  public static let operationName: String = "CreateTrip"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"mutation CreateTrip($input: TripInput!) { createTrip(input: $input) { __typename id name tripDescription startDate endDate updatedAt } }"#
    ))

  public var input: TripInput

  public init(input: TripInput) {
    self.input = input
  }

  public var __variables: Variables? { ["input": input] }

  public struct Data: JourniaryAPI.SelectionSet {
    public let __data: DataDict
    public init(_dataDict: DataDict) { __data = _dataDict }

    public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.Mutation }
    public static var __selections: [ApolloAPI.Selection] { [
      .field("createTrip", CreateTrip.self, arguments: ["input": .variable("input")]),
    ] }

    /// Create a new trip
    public var createTrip: CreateTrip { __data["createTrip"] }

    /// CreateTrip
    ///
    /// Parent Type: `Trip`
    public struct CreateTrip: JourniaryAPI.SelectionSet {
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
