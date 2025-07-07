// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class DeleteTagMutation: GraphQLMutation {
  public static let operationName: String = "DeleteTag"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"mutation DeleteTag($id: String!) { deleteTag(id: $id) }"#
    ))

  public var id: String

  public init(id: String) {
    self.id = id
  }

  public var __variables: Variables? { ["id": id] }

  public struct Data: JourniaryAPI.SelectionSet {
    public let __data: DataDict
    public init(_dataDict: DataDict) { __data = _dataDict }

    public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.Mutation }
    public static var __selections: [ApolloAPI.Selection] { [
      .field("deleteTag", Bool.self, arguments: ["id": .variable("id")]),
    ] }

    public var deleteTag: Bool { __data["deleteTag"] }
  }
}
