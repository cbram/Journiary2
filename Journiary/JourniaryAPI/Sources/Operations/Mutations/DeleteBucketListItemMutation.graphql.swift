// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class DeleteBucketListItemMutation: GraphQLMutation {
  public static let operationName: String = "DeleteBucketListItem"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"mutation DeleteBucketListItem($id: ID!) { deleteBucketListItem(id: $id) }"#
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
      .field("deleteBucketListItem", Bool.self, arguments: ["id": .variable("id")]),
    ] }

    public var deleteBucketListItem: Bool { __data["deleteBucketListItem"] }
  }
}
