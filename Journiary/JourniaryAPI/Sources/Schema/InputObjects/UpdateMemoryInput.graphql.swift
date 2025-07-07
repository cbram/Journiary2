// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

/// Update memory data
public struct UpdateMemoryInput: InputObject {
  public private(set) var __data: InputDict

  public init(_ data: InputDict) {
    __data = data
  }

  public init(
    title: GraphQLNullable<String> = nil,
    content: GraphQLNullable<String> = nil,
    date: GraphQLNullable<DateTime> = nil,
    latitude: GraphQLNullable<Double> = nil,
    longitude: GraphQLNullable<Double> = nil,
    location: GraphQLNullable<LocationInput> = nil,
    address: GraphQLNullable<String> = nil,
    tagIds: GraphQLNullable<[String]> = nil
  ) {
    __data = InputDict([
      "title": title,
      "content": content,
      "date": date,
      "latitude": latitude,
      "longitude": longitude,
      "location": location,
      "address": address,
      "tagIds": tagIds
    ])
  }

  public var title: GraphQLNullable<String> {
    get { __data["title"] }
    set { __data["title"] = newValue }
  }

  public var content: GraphQLNullable<String> {
    get { __data["content"] }
    set { __data["content"] = newValue }
  }

  public var date: GraphQLNullable<DateTime> {
    get { __data["date"] }
    set { __data["date"] = newValue }
  }

  public var latitude: GraphQLNullable<Double> {
    get { __data["latitude"] }
    set { __data["latitude"] = newValue }
  }

  public var longitude: GraphQLNullable<Double> {
    get { __data["longitude"] }
    set { __data["longitude"] = newValue }
  }

  public var location: GraphQLNullable<LocationInput> {
    get { __data["location"] }
    set { __data["location"] = newValue }
  }

  public var address: GraphQLNullable<String> {
    get { __data["address"] }
    set { __data["address"] = newValue }
  }

  /// A list of Tag IDs to associate with this memory
  public var tagIds: GraphQLNullable<[String]> {
    get { __data["tagIds"] }
    set { __data["tagIds"] = newValue }
  }
}
