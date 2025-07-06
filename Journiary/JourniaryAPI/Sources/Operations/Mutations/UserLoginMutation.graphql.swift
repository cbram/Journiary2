// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class UserLoginMutation: GraphQLMutation {
  public static let operationName: String = "UserLogin"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"mutation UserLogin($input: UserInput!) { login(input: $input) { __typename token user { __typename id email username displayName } } }"#
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
      .field("login", Login.self, arguments: ["input": .variable("input")]),
    ] }

    /// Log in a user
    public var login: Login { __data["login"] }

    /// Login
    ///
    /// Parent Type: `AuthResponse`
    public struct Login: JourniaryAPI.SelectionSet {
      public let __data: DataDict
      public init(_dataDict: DataDict) { __data = _dataDict }

      public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.AuthResponse }
      public static var __selections: [ApolloAPI.Selection] { [
        .field("__typename", String.self),
        .field("token", String.self),
        .field("user", User.self),
      ] }

      public var token: String { __data["token"] }
      public var user: User { __data["user"] }

      /// Login.User
      ///
      /// Parent Type: `User`
      public struct User: JourniaryAPI.SelectionSet {
        public let __data: DataDict
        public init(_dataDict: DataDict) { __data = _dataDict }

        public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.User }
        public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("id", JourniaryAPI.ID.self),
          .field("email", String.self),
          .field("username", String.self),
          .field("displayName", String.self),
        ] }

        public var id: JourniaryAPI.ID { __data["id"] }
        public var email: String { __data["email"] }
        public var username: String { __data["username"] }
        public var displayName: String { __data["displayName"] }
      }
    }
  }
}
