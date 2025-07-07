// @generated
// This file was automatically generated and should not be edited.

@_exported import ApolloAPI

public class SyncQuery: GraphQLQuery {
  public static let operationName: String = "Sync"
  public static let operationDocument: ApolloAPI.OperationDocument = .init(
    definition: .init(
      #"query Sync($lastSyncedAt: DateTime!) { sync(lastSyncedAt: $lastSyncedAt) { __typename trips { __typename id name tripDescription travelCompanions visitedCountries startDate endDate isActive totalDistance gpsTrackingEnabled createdAt updatedAt } memories { __typename id title text timestamp latitude longitude locationName createdAt updatedAt tripId } tags { __typename id name emoji color isSystemTag usageCount createdAt updatedAt categoryId tagDescription } tagCategories { __typename id name displayName emoji color isSystemCategory sortOrder isExpanded createdAt updatedAt } bucketListItems { __typename id name country region type latitude1 longitude1 latitude2 longitude2 isDone createdAt updatedAt completedAt } mediaItems { __typename id filename originalFilename mimeType timestamp order fileSize duration createdAt updatedAt memory { __typename id } } gpxTracks { __typename id name originalFilename creator trackType createdAt updatedAt tripId } deleted { __typename trips memories tags tagCategories mediaItems gpxTracks bucketListItems } serverTimestamp } }"#
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
        .field("tags", [Tag].self),
        .field("tagCategories", [TagCategory].self),
        .field("bucketListItems", [BucketListItem].self),
        .field("mediaItems", [MediaItem].self),
        .field("gpxTracks", [GpxTrack].self),
        .field("deleted", Deleted.self),
        .field("serverTimestamp", JourniaryAPI.DateTime.self),
      ] }

      public var trips: [Trip] { __data["trips"] }
      public var memories: [Memory] { __data["memories"] }
      public var tags: [Tag] { __data["tags"] }
      public var tagCategories: [TagCategory] { __data["tagCategories"] }
      public var bucketListItems: [BucketListItem] { __data["bucketListItems"] }
      public var mediaItems: [MediaItem] { __data["mediaItems"] }
      public var gpxTracks: [GpxTrack] { __data["gpxTracks"] }
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

      /// Sync.Tag
      ///
      /// Parent Type: `Tag`
      public struct Tag: JourniaryAPI.SelectionSet {
        public let __data: DataDict
        public init(_dataDict: DataDict) { __data = _dataDict }

        public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.Tag }
        public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("id", JourniaryAPI.ID.self),
          .field("name", String.self),
          .field("emoji", String?.self),
          .field("color", String?.self),
          .field("isSystemTag", Bool.self),
          .field("usageCount", Int.self),
          .field("createdAt", JourniaryAPI.DateTime.self),
          .field("updatedAt", JourniaryAPI.DateTime.self),
          .field("categoryId", String?.self),
          .field("tagDescription", String?.self),
        ] }

        public var id: JourniaryAPI.ID { __data["id"] }
        public var name: String { __data["name"] }
        public var emoji: String? { __data["emoji"] }
        public var color: String? { __data["color"] }
        public var isSystemTag: Bool { __data["isSystemTag"] }
        public var usageCount: Int { __data["usageCount"] }
        public var createdAt: JourniaryAPI.DateTime { __data["createdAt"] }
        public var updatedAt: JourniaryAPI.DateTime { __data["updatedAt"] }
        public var categoryId: String? { __data["categoryId"] }
        public var tagDescription: String? { __data["tagDescription"] }
      }

      /// Sync.TagCategory
      ///
      /// Parent Type: `TagCategory`
      public struct TagCategory: JourniaryAPI.SelectionSet {
        public let __data: DataDict
        public init(_dataDict: DataDict) { __data = _dataDict }

        public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.TagCategory }
        public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("id", JourniaryAPI.ID.self),
          .field("name", String.self),
          .field("displayName", String?.self),
          .field("emoji", String?.self),
          .field("color", String?.self),
          .field("isSystemCategory", Bool.self),
          .field("sortOrder", Int.self),
          .field("isExpanded", Bool.self),
          .field("createdAt", JourniaryAPI.DateTime.self),
          .field("updatedAt", JourniaryAPI.DateTime.self),
        ] }

        public var id: JourniaryAPI.ID { __data["id"] }
        public var name: String { __data["name"] }
        public var displayName: String? { __data["displayName"] }
        public var emoji: String? { __data["emoji"] }
        public var color: String? { __data["color"] }
        public var isSystemCategory: Bool { __data["isSystemCategory"] }
        public var sortOrder: Int { __data["sortOrder"] }
        public var isExpanded: Bool { __data["isExpanded"] }
        public var createdAt: JourniaryAPI.DateTime { __data["createdAt"] }
        public var updatedAt: JourniaryAPI.DateTime { __data["updatedAt"] }
      }

      /// Sync.BucketListItem
      ///
      /// Parent Type: `BucketListItem`
      public struct BucketListItem: JourniaryAPI.SelectionSet {
        public let __data: DataDict
        public init(_dataDict: DataDict) { __data = _dataDict }

        public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.BucketListItem }
        public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("id", JourniaryAPI.ID.self),
          .field("name", String.self),
          .field("country", String?.self),
          .field("region", String?.self),
          .field("type", String?.self),
          .field("latitude1", Double?.self),
          .field("longitude1", Double?.self),
          .field("latitude2", Double?.self),
          .field("longitude2", Double?.self),
          .field("isDone", Bool.self),
          .field("createdAt", JourniaryAPI.DateTime.self),
          .field("updatedAt", JourniaryAPI.DateTime.self),
          .field("completedAt", JourniaryAPI.DateTime?.self),
        ] }

        public var id: JourniaryAPI.ID { __data["id"] }
        public var name: String { __data["name"] }
        public var country: String? { __data["country"] }
        public var region: String? { __data["region"] }
        public var type: String? { __data["type"] }
        public var latitude1: Double? { __data["latitude1"] }
        public var longitude1: Double? { __data["longitude1"] }
        public var latitude2: Double? { __data["latitude2"] }
        public var longitude2: Double? { __data["longitude2"] }
        public var isDone: Bool { __data["isDone"] }
        public var createdAt: JourniaryAPI.DateTime { __data["createdAt"] }
        public var updatedAt: JourniaryAPI.DateTime { __data["updatedAt"] }
        public var completedAt: JourniaryAPI.DateTime? { __data["completedAt"] }
      }

      /// Sync.MediaItem
      ///
      /// Parent Type: `MediaItem`
      public struct MediaItem: JourniaryAPI.SelectionSet {
        public let __data: DataDict
        public init(_dataDict: DataDict) { __data = _dataDict }

        public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.MediaItem }
        public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("id", JourniaryAPI.ID.self),
          .field("filename", String.self),
          .field("originalFilename", String?.self),
          .field("mimeType", String.self),
          .field("timestamp", JourniaryAPI.DateTime.self),
          .field("order", Int.self),
          .field("fileSize", Int.self),
          .field("duration", Double?.self),
          .field("createdAt", JourniaryAPI.DateTime.self),
          .field("updatedAt", JourniaryAPI.DateTime.self),
          .field("memory", Memory.self),
        ] }

        public var id: JourniaryAPI.ID { __data["id"] }
        public var filename: String { __data["filename"] }
        public var originalFilename: String? { __data["originalFilename"] }
        public var mimeType: String { __data["mimeType"] }
        public var timestamp: JourniaryAPI.DateTime { __data["timestamp"] }
        /// The order of this item within the memory's media list
        public var order: Int { __data["order"] }
        public var fileSize: Int { __data["fileSize"] }
        /// For videos, the duration in seconds.
        public var duration: Double? { __data["duration"] }
        public var createdAt: JourniaryAPI.DateTime { __data["createdAt"] }
        public var updatedAt: JourniaryAPI.DateTime { __data["updatedAt"] }
        public var memory: Memory { __data["memory"] }

        /// Sync.MediaItem.Memory
        ///
        /// Parent Type: `Memory`
        public struct Memory: JourniaryAPI.SelectionSet {
          public let __data: DataDict
          public init(_dataDict: DataDict) { __data = _dataDict }

          public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.Memory }
          public static var __selections: [ApolloAPI.Selection] { [
            .field("__typename", String.self),
            .field("id", JourniaryAPI.ID.self),
          ] }

          public var id: JourniaryAPI.ID { __data["id"] }
        }
      }

      /// Sync.GpxTrack
      ///
      /// Parent Type: `GPXTrack`
      public struct GpxTrack: JourniaryAPI.SelectionSet {
        public let __data: DataDict
        public init(_dataDict: DataDict) { __data = _dataDict }

        public static var __parentType: any ApolloAPI.ParentType { JourniaryAPI.Objects.GPXTrack }
        public static var __selections: [ApolloAPI.Selection] { [
          .field("__typename", String.self),
          .field("id", JourniaryAPI.ID.self),
          .field("name", String.self),
          .field("originalFilename", String?.self),
          .field("creator", String?.self),
          .field("trackType", String?.self),
          .field("createdAt", JourniaryAPI.DateTime.self),
          .field("updatedAt", JourniaryAPI.DateTime.self),
          .field("tripId", JourniaryAPI.ID.self),
        ] }

        public var id: JourniaryAPI.ID { __data["id"] }
        public var name: String { __data["name"] }
        public var originalFilename: String? { __data["originalFilename"] }
        public var creator: String? { __data["creator"] }
        public var trackType: String? { __data["trackType"] }
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
