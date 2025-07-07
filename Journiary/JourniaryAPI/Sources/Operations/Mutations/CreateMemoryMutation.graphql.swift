// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class CreateMemoryMutation: GraphQLMutation {
  public static let operationName: String = "CreateMemory"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"mutation CreateMemory($input: MemoryInput!) { createMemory(input: $input) { __typename id updatedAt } }"#
    ))

  public var input: MemoryInput

  public init(input: MemoryInput) {
    self.input = input
  }

  public var __variables: Variables? { ["input": input] }

  public struct Data: JourniaryAPI.SelectionSet {
    public let __data: DataDict
    public init(_dataDict: DataDict) { __data = _dataDict }

    public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.Mutation }
    public static var __selections: [ApolloAPI.Selection] { [
      .field("createMemory", CreateMemory.self, arguments: ["input": .variable("input")]),
    ] }

    /// Create a new memory and associate it with a trip
    public var createMemory: CreateMemory { __data["createMemory"] }

    /// CreateMemory
    ///
    /// Parent Type: `Memory`
    public struct CreateMemory: JourniaryAPI.SelectionSet {
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
