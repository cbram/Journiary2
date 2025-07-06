// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class SyncQuery: GraphQLQuery {
  public static let operationName: String = "Sync"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"query Sync($lastSyncedAt: DateTime) { sync(lastSyncedAt: $lastSyncedAt) { __typename trips { __typename id name tripDescription travelCompanions visitedCountries startDate endDate isActive totalDistance gpsTrackingEnabled createdAt updatedAt } deletedIds { __typename id entityName } timestamp } }"#
    ))

  public var lastSyncedAt: GraphQLNullable<DateTime>

  public init(lastSyncedAt: GraphQLNullable<DateTime>) {
    self.lastSyncedAt = lastSyncedAt
  }

  public var __variables: Variables? { ["lastSyncedAt": lastSyncedAt] }

  public struct Data: JourniaryAPI.SelectionSet {
    public let __data: DataDict
    public init(_dataDict: DataDict) { __data = _dataDict }

    public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.Query }
    public static var __selections: [ApolloAPI.Selection] { [
      .field("sync", Sync.self, arguments: ["lastSyncedAt": .variable("lastSyncedAt")]),
    ] }

    /// Performs an incremental sync.
    public var sync: Sync { __data["sync"] }

    /// Sync
    ///
    /// Parent Type: `SyncResponse`
    public struct Sync: JourniaryAPI.SelectionSet {
      public let __data: DataDict
      public init(_dataDict: DataDict) { __data = _dataDict }

      public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.SyncResponse }
      public static var __selections: [ApolloAPI.Selection] { [
        .field("__typename", String.self),
        .field("trips", [Trip].self),
        .field("deletedIds", [DeletedId].self),
        .field("timestamp", JourniaryAPI.DateTime.self),
      ] }

      /// A list of trips that have been created or updated since the last sync.
      public var trips: [Trip] { __data["trips"] }
      /// A list of objects that have been deleted since the last sync.
      public var deletedIds: [DeletedId] { __data["deletedIds"] }
      /// The timestamp of this sync operation, to be used as `lastSyncedAt` in the next sync.
      public var timestamp: JourniaryAPI.DateTime { __data["timestamp"] }

      /// Sync.Trip
      ///
      /// Parent Type: `Trip`
      public struct Trip: JourniaryAPI.SelectionSet {
        public let __data: DataDict
        public init(_dataDict: DataDict) { __data = _dataDict }

        public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.Trip }
        public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("id", JourniaryAPI.ID.self),
          .field("name", String.self),
          .field("tripDescription", String?.self),
          .field("travelCompanions", String?.self),
          .field("visitedCountries", String?.self),
          .field("startDate", JourniaryAPI.DateTime.self),
          .field("endDate", JourniaryAPI.DateTime?.self),
          .field("isActive", Bool.self),
          .field("totalDistance", Double.self),
          .field("gpsTrackingEnabled", Bool.self),
          .field("createdAt", JourniaryAPI.DateTime.self),
          .field("updatedAt", JourniaryAPI.DateTime.self),
        ] }

        public var id: JourniaryAPI.ID { __data["id"] }
        public var name: String { __data["name"] }
        public var tripDescription: String? { __data["tripDescription"] }
        public var travelCompanions: String? { __data["travelCompanions"] }
        public var visitedCountries: String? { __data["visitedCountries"] }
        public var startDate: JourniaryAPI.DateTime { __data["startDate"] }
        public var endDate: JourniaryAPI.DateTime? { __data["endDate"] }
        public var isActive: Bool { __data["isActive"] }
        public var totalDistance: Double { __data["totalDistance"] }
        public var gpsTrackingEnabled: Bool { __data["gpsTrackingEnabled"] }
        public var createdAt: JourniaryAPI.DateTime { __data["createdAt"] }
        public var updatedAt: JourniaryAPI.DateTime { __data["updatedAt"] }
      }

      /// Sync.DeletedId
      ///
      /// Parent Type: `Deletion`
      public struct DeletedId: JourniaryAPI.SelectionSet {
        public let __data: DataDict
        public init(_dataDict: DataDict) { __data = _dataDict }

        public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.Deletion }
        public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("id", JourniaryAPI.ID.self),
          .field("entityName", String.self),
        ] }

        /// The ID of the deleted entity.
        public var id: JourniaryAPI.ID { __data["id"] }
        /// The type of the deleted entity (e.g., 'Trip', 'Memory').
        public var entityName: String { __data["entityName"] }
      }
    }
  }
}
