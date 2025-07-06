// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class UserRegistrationMutation: GraphQLMutation {
  public static let operationName: String = "UserRegistration"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"mutation UserRegistration($input: UserInput!) { register(input: $input) { __typename id email } }"#
    ))

  public var input: UserInput

  public init(input: UserInput) {
    self.input = input
  }

  public var __variables: Variables? { ["input": input] }

  public struct Data: JourniaryAPI.SelectionSet {
    public let __data: DataDict
    public init(_dataDict: DataDict) { __data = _dataDict }

    public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.Mutation }
    public static var __selections: [ApolloAPI.Selection] { [
      .field("register", Register.self, arguments: ["input": .variable("input")]),
    ] }

    /// Register a new user
    public var register: Register { __data["register"] }

    /// Register
    ///
    /// Parent Type: `User`
    public struct Register: JourniaryAPI.SelectionSet {
      public let __data: DataDict
      public init(_dataDict: DataDict) { __data = _dataDict }

      public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.User }
      public static var __selections: [ApolloAPI.Selection] { [
        .field("__typename", String.self),
        .field("id", JourniaryAPI.ID.self),
        .field("email", String.self),
      ] }

      public var id: JourniaryAPI.ID { __data["id"] }
      public var email: String { __data["email"] }
    }
  }
}
