// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class UpdateBucketListItemMutation: GraphQLMutation {
  public static let operationName: String = "UpdateBucketListItem"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"mutation UpdateBucketListItem($id: ID!, $input: BucketListItemInput!) { updateBucketListItem(id: $id, input: $input) { __typename id name country region type latitude1 longitude1 latitude2 longitude2 isDone createdAt updatedAt completedAt } }"#
    ))

  public var id: ID
  public var input: BucketListItemInput

  public init(
    id: ID,
    input: BucketListItemInput
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
      .field("updateBucketListItem", UpdateBucketListItem?.self, arguments: [
        "id": .variable("id"),
        "input": .variable("input")
      ]),
    ] }

    public var updateBucketListItem: UpdateBucketListItem? { __data["updateBucketListItem"] }

    /// UpdateBucketListItem
    ///
    /// Parent Type: `BucketListItem`
    public struct UpdateBucketListItem: JourniaryAPI.SelectionSet {
      public let __data: DataDict
      public init(_dataDict: DataDict) { __data = _dataDict }

      public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.BucketListItem }
      public static var __selections: [ApolloAPI.Selection] { [
        .field("__typename", String.self),
        .field("id", JourniaryAPI.ID.self),
        .field("name", String.self),
        .field("country", String?.self),
        .field("region", String?.self),
        .field("type", String?.self),
        .field("latitude1", Double?.self),
        .field("longitude1", Double?.self),
        .field("latitude2", Double?.self),
        .field("longitude2", Double?.self),
        .field("isDone", Bool.self),
        .field("createdAt", JourniaryAPI.DateTime.self),
        .field("updatedAt", JourniaryAPI.DateTime.self),
        .field("completedAt", JourniaryAPI.DateTime?.self),
      ] }

      public var id: JourniaryAPI.ID { __data["id"] }
      public var name: String { __data["name"] }
      public var country: String? { __data["country"] }
      public var region: String? { __data["region"] }
      public var type: String? { __data["type"] }
      public var latitude1: Double? { __data["latitude1"] }
      public var longitude1: Double? { __data["longitude1"] }
      public var latitude2: Double? { __data["latitude2"] }
      public var longitude2: Double? { __data["longitude2"] }
      public var isDone: Bool { __data["isDone"] }
      public var createdAt: JourniaryAPI.DateTime { __data["createdAt"] }
      public var updatedAt: JourniaryAPI.DateTime { __data["updatedAt"] }
      public var completedAt: JourniaryAPI.DateTime? { __data["completedAt"] }
    }
  }
}
