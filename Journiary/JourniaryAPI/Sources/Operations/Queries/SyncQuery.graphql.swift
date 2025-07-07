// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class SyncQuery: GraphQLQuery {
  public static let operationName: String = "Sync"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"query Sync($lastSyncedAt: DateTime!) { sync(lastSyncedAt: $lastSyncedAt) { __typename trips { __typename id name tripDescription travelCompanions visitedCountries startDate endDate isActive totalDistance gpsTrackingEnabled createdAt updatedAt } memories { __typename id title text timestamp latitude longitude locationName createdAt updatedAt tripId } deleted { __typename trips memories tags tagCategories mediaItems gpxTracks bucketListItems } serverTimestamp } }"#
    ))

  public var lastSyncedAt: DateTime

  public init(lastSyncedAt: DateTime) {
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
        .field("memories", [Memory].self),
        .field("deleted", Deleted.self),
        .field("serverTimestamp", JourniaryAPI.DateTime.self),
      ] }

      public var trips: [Trip] { __data["trips"] }
      public var memories: [Memory] { __data["memories"] }
      public var deleted: Deleted { __data["deleted"] }
      public var serverTimestamp: JourniaryAPI.DateTime { __data["serverTimestamp"] }

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

      /// Sync.Memory
      ///
      /// Parent Type: `Memory`
      public struct Memory: JourniaryAPI.SelectionSet {
        public let __data: DataDict
        public init(_dataDict: DataDict) { __data = _dataDict }

        public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.Memory }
        public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("id", JourniaryAPI.ID.self),
          .field("title", String.self),
          .field("text", String?.self),
          .field("timestamp", JourniaryAPI.DateTime.self),
          .field("latitude", Double.self),
          .field("longitude", Double.self),
          .field("locationName", String?.self),
          .field("createdAt", JourniaryAPI.DateTime.self),
          .field("updatedAt", JourniaryAPI.DateTime.self),
          .field("tripId", JourniaryAPI.ID.self),
        ] }

        public var id: JourniaryAPI.ID { __data["id"] }
        public var title: String { __data["title"] }
        public var text: String? { __data["text"] }
        public var timestamp: JourniaryAPI.DateTime { __data["timestamp"] }
        public var latitude: Double { __data["latitude"] }
        public var longitude: Double { __data["longitude"] }
        public var locationName: String? { __data["locationName"] }
        public var createdAt: JourniaryAPI.DateTime { __data["createdAt"] }
        public var updatedAt: JourniaryAPI.DateTime { __data["updatedAt"] }
        public var tripId: JourniaryAPI.ID { __data["tripId"] }
      }

      /// Sync.Deleted
      ///
      /// Parent Type: `DeletedIds`
      public struct Deleted: JourniaryAPI.SelectionSet {
        public let __data: DataDict
        public init(_dataDict: DataDict) { __data = _dataDict }

        public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.DeletedIds }
        public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("trips", [JourniaryAPI.ID].self),
          .field("memories", [JourniaryAPI.ID].self),
          .field("tags", [JourniaryAPI.ID].self),
          .field("tagCategories", [JourniaryAPI.ID].self),
          .field("mediaItems", [JourniaryAPI.ID].self),
          .field("gpxTracks", [JourniaryAPI.ID].self),
          .field("bucketListItems", [JourniaryAPI.ID].self),
        ] }

        public var trips: [JourniaryAPI.ID] { __data["trips"] }
        public var memories: [JourniaryAPI.ID] { __data["memories"] }
        public var tags: [JourniaryAPI.ID] { __data["tags"] }
        public var tagCategories: [JourniaryAPI.ID] { __data["tagCategories"] }
        public var mediaItems: [JourniaryAPI.ID] { __data["mediaItems"] }
        public var gpxTracks: [JourniaryAPI.ID] { __data["gpxTracks"] }
        public var bucketListItems: [JourniaryAPI.ID] { __data["bucketListItems"] }
      }
    }
  }
}
