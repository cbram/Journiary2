// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

/// New memory data
public struct MemoryInput: InputObject {
  public private(set) var __data: InputDict

  public init(_ data: InputDict) {
    __data = data
  }

  public init(
    title: String,
    content: GraphQLNullable<String> = nil,
    date: GraphQLNullable<DateTime> = nil,
    latitude: GraphQLNullable<Double> = nil,
    longitude: GraphQLNullable<Double> = nil,
    address: GraphQLNullable<String> = nil,
    location: GraphQLNullable<LocationInput> = nil,
    tripId: ID,
    tagIds: GraphQLNullable<[ID]> = nil
  ) {
    __data = InputDict([
      "title": title,
      "content": content,
      "date": date,
      "latitude": latitude,
      "longitude": longitude,
      "address": address,
      "location": location,
      "tripId": tripId,
      "tagIds": tagIds
    ])
  }

  public var title: String {
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

  public var address: GraphQLNullable<String> {
    get { __data["address"] }
    set { __data["address"] = newValue }
  }

  public var location: GraphQLNullable<LocationInput> {
    get { __data["location"] }
    set { __data["location"] = newValue }
  }

  /// The ID of the trip this memory belongs to
  public var tripId: ID {
    get { __data["tripId"] }
    set { __data["tripId"] = newValue }
  }

  /// A list of Tag IDs to associate with this memory
  public var tagIds: GraphQLNullable<[ID]> {
    get { __data["tagIds"] }
    set { __data["tagIds"] = newValue }
  }
}
