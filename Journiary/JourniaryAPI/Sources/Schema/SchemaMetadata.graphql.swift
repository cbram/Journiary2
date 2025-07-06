// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public protocol SelectionSet: ApolloAPI.SelectionSet & ApolloAPI.RootSelectionSet
where Schema == JourniaryAPI.SchemaMetadata {}

public protocol InlineFragment: ApolloAPI.SelectionSet & ApolloAPI.InlineFragment
where Schema == JourniaryAPI.SchemaMetadata {}

public protocol MutableSelectionSet: ApolloAPI.MutableRootSelectionSet
where Schema == JourniaryAPI.SchemaMetadata {}

public protocol MutableInlineFragment: ApolloAPI.MutableSelectionSet & ApolloAPI.InlineFragment
where Schema == JourniaryAPI.SchemaMetadata {}

public enum SchemaMetadata: ApolloAPI.SchemaMetadata {
  public static let configuration: any ApolloAPI.SchemaConfiguration.Type = SchemaConfiguration.self

  public static func objectType(forTypename typename: String) -> ApolloAPI.Object? {
    switch typename {
    case "AuthResponse": return JourniaryAPI.Objects.AuthResponse
    case "Deletion": return JourniaryAPI.Objects.Deletion
    case "Mutation": return JourniaryAPI.Objects.Mutation
    case "Query": return JourniaryAPI.Objects.Query
    case "SyncResponse": return JourniaryAPI.Objects.SyncResponse
    case "Trip": return JourniaryAPI.Objects.Trip
    case "User": return JourniaryAPI.Objects.User
    default: return nil
    }
  }
}

public enum Objects {}
public enum Interfaces {}
public enum Unions {}
