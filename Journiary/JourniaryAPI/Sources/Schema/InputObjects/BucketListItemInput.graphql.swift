// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

public struct BucketListItemInput: InputObject {
  public private(set) var __data: InputDict

  public init(_ data: InputDict) {
    __data = data
  }

  public init(
    name: String,
    country: GraphQLNullable<String> = nil,
    region: GraphQLNullable<String> = nil,
    type: GraphQLNullable<String> = nil,
    latitude1: GraphQLNullable<Double> = nil,
    longitude1: GraphQLNullable<Double> = nil,
    latitude2: GraphQLNullable<Double> = nil,
    longitude2: GraphQLNullable<Double> = nil,
    isDone: GraphQLNullable<Bool> = nil
  ) {
    __data = InputDict([
      "name": name,
      "country": country,
      "region": region,
      "type": type,
      "latitude1": latitude1,
      "longitude1": longitude1,
      "latitude2": latitude2,
      "longitude2": longitude2,
      "isDone": isDone
    ])
  }

  public var name: String {
    get { __data["name"] }
    set { __data["name"] = newValue }
  }

  public var country: GraphQLNullable<String> {
    get { __data["country"] }
    set { __data["country"] = newValue }
  }

  public var region: GraphQLNullable<String> {
    get { __data["region"] }
    set { __data["region"] = newValue }
  }

  public var type: GraphQLNullable<String> {
    get { __data["type"] }
    set { __data["type"] = newValue }
  }

  public var latitude1: GraphQLNullable<Double> {
    get { __data["latitude1"] }
    set { __data["latitude1"] = newValue }
  }

  public var longitude1: GraphQLNullable<Double> {
    get { __data["longitude1"] }
    set { __data["longitude1"] = newValue }
  }

  public var latitude2: GraphQLNullable<Double> {
    get { __data["latitude2"] }
    set { __data["latitude2"] = newValue }
  }

  public var longitude2: GraphQLNullable<Double> {
    get { __data["longitude2"] }
    set { __data["longitude2"] = newValue }
  }

  public var isDone: GraphQLNullable<Bool> {
    get { __data["isDone"] }
    set { __data["isDone"] = newValue }
  }
}
