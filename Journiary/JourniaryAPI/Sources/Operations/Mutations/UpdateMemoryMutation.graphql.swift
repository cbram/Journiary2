// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class UpdateMemoryMutation: GraphQLMutation {
  public static let operationName: String = "UpdateMemory"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"mutation UpdateMemory($id: String!, $input: UpdateMemoryInput!) { updateMemory(id: $id, input: $input) { __typename id updatedAt } }"#
    ))

  public var id: String
  public var input: UpdateMemoryInput

  public init(
    id: String,
    input: UpdateMemoryInput
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
      .field("updateMemory", UpdateMemory.self, arguments: [
        "id": .variable("id"),
        "input": .variable("input")
      ]),
    ] }

    /// Update an existing memory
    public var updateMemory: UpdateMemory { __data["updateMemory"] }

    /// UpdateMemory
    ///
    /// Parent Type: `Memory`
    public struct UpdateMemory: JourniaryAPI.SelectionSet {
      public let __data: DataDict
      public init(_dataDict: DataDict) { __data = _dataDict }

      public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.Memory }
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
