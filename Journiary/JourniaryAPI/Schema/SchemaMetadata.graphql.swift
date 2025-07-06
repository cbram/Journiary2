// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

protocol JourniaryAPI_SelectionSet: ApolloAPI.SelectionSet & ApolloAPI.RootSelectionSet
where Schema == JourniaryAPI.SchemaMetadata {}

protocol JourniaryAPI_InlineFragment: ApolloAPI.SelectionSet & ApolloAPI.InlineFragment
where Schema == JourniaryAPI.SchemaMetadata {}

protocol JourniaryAPI_MutableSelectionSet: ApolloAPI.MutableRootSelectionSet
where Schema == JourniaryAPI.SchemaMetadata {}

protocol JourniaryAPI_MutableInlineFragment: ApolloAPI.MutableSelectionSet & ApolloAPI.InlineFragment
where Schema == JourniaryAPI.SchemaMetadata {}

extension JourniaryAPI {
  typealias ID = String

  typealias SelectionSet = JourniaryAPI_SelectionSet

  typealias InlineFragment = JourniaryAPI_InlineFragment

  typealias MutableSelectionSet = JourniaryAPI_MutableSelectionSet

  typealias MutableInlineFragment = JourniaryAPI_MutableInlineFragment

  enum SchemaMetadata: ApolloAPI.SchemaMetadata {
    static let configuration: ApolloAPI.SchemaConfiguration.Type = SchemaConfiguration.self

    static func objectType(forTypename typename: String) -> ApolloAPI.Object? {
      switch typename {
      case "Mutation": return JourniaryAPI.Objects.Mutation
      case "AuthResponse": return JourniaryAPI.Objects.AuthResponse
      case "User": return JourniaryAPI.Objects.User
      default: return nil
      }
    }
  }

  enum Objects {}
  enum Interfaces {}
  enum Unions {}

}