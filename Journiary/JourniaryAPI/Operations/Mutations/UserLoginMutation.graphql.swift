// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

extension JourniaryAPI {
  class UserLoginMutation: GraphQLMutation {
    static let operationName: String = "UserLogin"
    static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation UserLogin($input: UserInput!) { login(input: $input) { __typename token user { __typename id email username displayName } } }"#
      ))

    public var input: UserInput

    public init(input: UserInput) {
      self.input = input
    }

    public var __variables: Variables? { ["input": input] }

    struct Data: JourniaryAPI.SelectionSet {
      let __data: DataDict
      init(_dataDict: DataDict) { __data = _dataDict }

      static var __parentType: ApolloAPI.ParentType { JourniaryAPI.Objects.Mutation }
      static var __selections: [ApolloAPI.Selection] { [
        .field("login", Login.self, arguments: ["input": .variable("input")]),
      ] }

      /// Log in a user
      var login: Login { __data["login"] }

      /// Login
      ///
      /// Parent Type: `AuthResponse`
      struct Login: JourniaryAPI.SelectionSet {
        let __data: DataDict
        init(_dataDict: DataDict) { __data = _dataDict }

        static var __parentType: ApolloAPI.ParentType { JourniaryAPI.Objects.AuthResponse }
        static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("token", String.self),
          .field("user", User.self),
        ] }

        var token: String { __data["token"] }
        var user: User { __data["user"] }

        /// Login.User
        ///
        /// Parent Type: `User`
        struct User: JourniaryAPI.SelectionSet {
          let __data: DataDict
          init(_dataDict: DataDict) { __data = _dataDict }

          static var __parentType: ApolloAPI.ParentType { JourniaryAPI.Objects.User }
          static var __selections: [ApolloAPI.Selection] { [
            .field("__typename", String.self),
            .field("id", JourniaryAPI.ID.self),
            .field("email", String.self),
            .field("username", String.self),
            .field("displayName", String.self),
          ] }

          var id: JourniaryAPI.ID { __data["id"] }
          var email: String { __data["email"] }
          var username: String { __data["username"] }
          var displayName: String { __data["displayName"] }
        }
      }
    }
  }

}