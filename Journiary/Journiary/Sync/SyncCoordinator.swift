//
//  SyncCoordinator.swift
//  Journiary
//
//  Zentraler Einstiegspunkt für die neue Sync-Layer-Architektur.
//  Steuert Upload-, Download- und Queue-Verarbeitung. (Schritt 1.1)
//

import Foundation
import Combine

final class SyncCoordinator: ObservableObject {

    static let shared = SyncCoordinator()

    // MARK: - Dependencies
    private let backendSyncService = GraphQLSyncService()
    private let cloudKitSyncService = CloudKitSyncService()
    private let queue = SyncQueue.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - API

    /// Startet einen vollständigen Sync-Durchlauf.
    /// – Prüft zunächst, ob ausstehende Queue-Einträge verarbeitet werden können.
    /// – Führt anschließend reguläre Upload- und Download-Phasen aus.
    func startFullSync() {
        guard !backendSyncService.isSyncing else { return }

        processQueue()

        switch AppSettings.shared.storageMode {
        case .backend:
            backendSyncService.performFullSync()
                .sink(
                    receiveCompletion: { completion in
                        if case let .failure(error) = completion {
                            print("❌ Backend-Sync fehlgeschlagen: \(error)")
                        }
                    },
                    receiveValue: { success in
                        if success {
                            print("✅ Backend-Sync abgeschlossen")
                        }
                    }
                )
                .store(in: &cancellables)

        case .cloudKit:
            cloudKitSyncService.performFullSync()
                .sink(
                    receiveCompletion: { completion in
                        if case let .failure(error) = completion {
                            print("❌ CloudKit-Sync fehlgeschlagen: \(error)")
                        }
                    },
                    receiveValue: { success in
                        if success {
                            print("✅ CloudKit-Sync abgeschlossen")
                        }
                    }
                )
                .store(in: &cancellables)

        case .hybrid:
            // Backend-Sync
            backendSyncService.performFullSync()
                .sink(receiveCompletion: { completion in
                    if case let .failure(error) = completion {
                        print("❌ Backend-Teil des Hybrid-Sync fehlgeschlagen: \(error)")
                    } else {
                        // Nach erfolgreichem Backend-Sync CloudKit-Sync starten
                        self.cloudKitSyncService.performFullSync()
                            .sink(
                                receiveCompletion: { ckCompletion in
                                    if case let .failure(ckError) = ckCompletion {
                                        print("❌ CloudKit-Teil des Hybrid-Sync fehlgeschlagen: \(ckError)")
                                    }
                                },
                                receiveValue: { ckSuccess in
                                    if ckSuccess {
                                        print("✅ Hybrid-Sync abgeschlossen")
                                    }
                                }
                            )
                            .store(in: &self.cancellables)
                    }
                }, receiveValue: { _ in })
                .store(in: &cancellables)
        }
    }

    // MARK: - Queue Handling

    /// Arbeitet alle wartenden Operationen ab, sofern die Backend-Verbindung verfügbar ist.
    private func processQueue() {
        guard AppSettings.shared.shouldUseBackend else { return }
        guard !queue.pendingOperations.isEmpty else { return }

        print("📤 Verarbeite \(queue.pendingOperations.count) ausstehende Queue-Operation(en)...")

        // Very first iteration: Wir versuchen, alle Operationen sofort auszuführen.
        // Unterstützt momentan Trip/Memory Create/Update/Delete im Backend-Pfad.
        let operations = queue.pendingOperations
        for op in operations {
            var success = false

            switch (AppSettings.shared.storageMode, op.entityName, op.operationType) {
            case (.backend, "Trip", .delete):
                success = true // TODO: DeleteTrip Mutation
            case (.backend, "Memory", .delete):
                if let id = op.entityId as String? {
                    let publisher = GraphQLMemoryService().deleteMemory(id: id)
                    let semaphore = DispatchSemaphore(value: 0)
                    publisher.sink(receiveCompletion: { completion in
                        if case .finished = completion { success = true }
                        semaphore.signal()
                    }, receiveValue: { _ in }).store(in: &cancellables)
                    semaphore.wait()
                }
            default:
                // Noch nicht implementiert → wird später behandelt
                break
            }

            if success {
                queue.removeOperation(id: op.id)
            }
        }
    }
} 