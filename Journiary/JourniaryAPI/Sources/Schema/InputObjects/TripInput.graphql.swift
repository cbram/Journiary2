// @generated
// This file was automatically generated and should not be edited.

import ApolloAPI

/// New trip data
public struct TripInput: InputObject {
  public private(set) var __data: InputDict

  public init(_ data: InputDict) {
    __data = data
  }

  public init(
    name: String,
    tripDescription: GraphQLNullable<String> = nil,
    travelCompanions: GraphQLNullable<String> = nil,
    visitedCountries: GraphQLNullable<String> = nil,
    startDate: DateTime,
    endDate: GraphQLNullable<DateTime> = nil,
    isActive: GraphQLNullable<Bool> = nil,
    totalDistance: GraphQLNullable<Double> = nil,
    gpsTrackingEnabled: GraphQLNullable<Bool> = nil
  ) {
    __data = InputDict([
      "name": name,
      "tripDescription": tripDescription,
      "travelCompanions": travelCompanions,
      "visitedCountries": visitedCountries,
      "startDate": startDate,
      "endDate": endDate,
      "isActive": isActive,
      "totalDistance": totalDistance,
      "gpsTrackingEnabled": gpsTrackingEnabled
    ])
  }

  public var name: String {
    get { __data["name"] }
    set { __data["name"] = newValue }
  }

  public var tripDescription: GraphQLNullable<String> {
    get { __data["tripDescription"] }
    set { __data["tripDescription"] = newValue }
  }

  public var travelCompanions: GraphQLNullable<String> {
    get { __data["travelCompanions"] }
    set { __data["travelCompanions"] = newValue }
  }

  public var visitedCountries: GraphQLNullable<String> {
    get { __data["visitedCountries"] }
    set { __data["visitedCountries"] = newValue }
  }

  public var startDate: DateTime {
    get { __data["startDate"] }
    set { __data["startDate"] = newValue }
  }

  public var endDate: GraphQLNullable<DateTime> {
    get { __data["endDate"] }
    set { __data["endDate"] = newValue }
  }

  public var isActive: GraphQLNullable<Bool> {
    get { __data["isActive"] }
    set { __data["isActive"] = newValue }
  }

  public var totalDistance: GraphQLNullable<Double> {
    get { __data["totalDistance"] }
    set { __data["totalDistance"] = newValue }
  }

  public var gpsTrackingEnabled: GraphQLNullable<Bool> {
    get { __data["gpsTrackingEnabled"] }
    set { __data["gpsTrackingEnabled"] = newValue }
  }
}
