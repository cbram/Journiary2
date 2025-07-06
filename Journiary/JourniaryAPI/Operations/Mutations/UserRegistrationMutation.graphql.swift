// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

extension JourniaryAPI {
  class UserRegistrationMutation: GraphQLMutation {
    static let operationName: String = "UserRegistration"
    static let operationDocument: ApolloAPI.OperationDocument = .init(
      definition: .init(
        #"mutation UserRegistration($input: UserInput!) { register(input: $input) { __typename id email } }"#
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
        .field("register", Register.self, arguments: ["input": .variable("input")]),
      ] }

      /// Register a new user
      var register: Register { __data["register"] }

      /// Register
      ///
      /// Parent Type: `User`
      struct Register: JourniaryAPI.SelectionSet {
        let __data: DataDict
        init(_dataDict: DataDict) { __data = _dataDict }

        static var __parentType: ApolloAPI.ParentType { JourniaryAPI.Objects.User }
        static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("id", JourniaryAPI.ID.self),
          .field("email", String.self),
        ] }

        var id: JourniaryAPI.ID { __data["id"] }
        var email: String { __data["email"] }
      }
    }
  }

}