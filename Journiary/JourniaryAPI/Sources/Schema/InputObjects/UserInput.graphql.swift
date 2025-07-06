// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

/// Input data for user registration and login
public struct UserInput: InputObject {
  public private(set) var __data: InputDict

  public init(_ data: InputDict) {
    __data = data
  }

  public init(
    email: String,
    password: String
  ) {
    __data = InputDict([
      "email": email,
      "password": password
    ])
  }

  public var email: String {
    get { __data["email"] }
    set { __data["email"] = newValue }
  }

  public var password: String {
    get { __data["password"] }
    set { __data["password"] = newValue }
  }
}
