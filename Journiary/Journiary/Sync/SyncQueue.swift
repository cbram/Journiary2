//
//  SyncQueue.swift
//  Journiary
//
//  Verantwortlich für das Verwalten der lokalen Sync-Warteschlange.
//  Persistiert als JSON im Application-Support-Verzeichnis, um Offline-Fähigkeit zu gewährleisten.
//

import Foundation
import Combine

final class SyncQueue: ObservableObject {
    static let shared = SyncQueue()

    // MARK: - Published
    @Published private(set) var pendingOperations: [SyncOperation] = []

    // MARK: - Private
    private let queueURL: URL
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let ioQueue = DispatchQueue(label: "com.journiary.syncQueue", qos: .utility)

    private init() {
        // Ablageort bestimmen
        let supportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        queueURL = supportURL.appendingPathComponent("sync_queue.json")

        // Bestehende Warteschlange laden
        loadQueueFromDisk()
    }

    // MARK: - Public API

    func addOperation(_ op: SyncOperation) {
        ioQueue.async {
            self.pendingOperations.append(op)
            self.saveQueueToDisk()
        }
    }

    func removeOperation(id: UUID) {
        ioQueue.async {
            self.pendingOperations.removeAll { $0.id == id }
            self.saveQueueToDisk()
        }
    }

    func clear() {
        ioQueue.async {
            self.pendingOperations.removeAll()
            self.saveQueueToDisk()
        }
    }

    // MARK: - Persistence

    private func loadQueueFromDisk() {
        ioQueue.sync {
            do {
                let data = try Data(contentsOf: queueURL)
                pendingOperations = try decoder.decode([SyncOperation].self, from: data)
            } catch {
                pendingOperations = [] // Datei fehlt oder korrupt → neu beginnen
            }
        }
    }

    private func saveQueueToDisk() {
        do {
            // Ordner anlegen, falls nicht vorhanden
            try FileManager.default.createDirectory(at: queueURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try encoder.encode(pendingOperations)
            try data.write(to: queueURL, options: [.atomic])
        } catch {
            print("⚠️ [SyncQueue] Speichern fehlgeschlagen: \(error)")
        }
    }
} 