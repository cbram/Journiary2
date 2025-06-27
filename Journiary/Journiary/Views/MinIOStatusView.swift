//
//  MinIOStatusView.swift
//  Journiary
//
//  Created by Assistant on 08.06.25.
//

import SwiftUI

struct MinIOStatusView: View {
    @ObservedObject private var minioClient = MinIOClient.shared
    @ObservedObject private var settings = AppSettings.shared
    
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("MinIO-Status")
                .font(.headline)
            
            connectionStatusView
            
            configurationStatusView
            
            Button(action: {
                testConnection()
            }) {
                HStack {
                    Image(systemName: "network")
                    Text("Verbindung testen")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(!minioClient.isConfigured)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        .alert(isPresented: $showingAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    private var connectionStatusView: some View {
        HStack {
            Text("Verbindungsstatus:")
                .fontWeight(.medium)
            
            Spacer()
            
            switch minioClient.connectionStatus {
            case .connected:
                HStack {
                    Text("Verbunden")
                        .foregroundColor(.green)
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            case .disconnected:
                HStack {
                    Text("Nicht verbunden")
                        .foregroundColor(.secondary)
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            case .error(let error):
                HStack {
                    Text("Fehler")
                        .foregroundColor(.red)
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                }
                .onTapGesture {
                    showAlert(title: "Verbindungsfehler", message: error.localizedDescription)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var configurationStatusView: some View {
        HStack {
            Text("Konfigurationsstatus:")
                .fontWeight(.medium)
            
            Spacer()
            
            if minioClient.isConfigured {
                HStack {
                    Text("Konfiguriert")
                        .foregroundColor(.green)
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            } else {
                HStack {
                    Text("Nicht konfiguriert")
                        .foregroundColor(.secondary)
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func testConnection() {
        // Hier würden wir die Verbindung testen
        // Für jetzt zeigen wir einfach den aktuellen Status an
        
        switch minioClient.connectionStatus {
        case .connected:
            showAlert(title: "Verbindung erfolgreich", message: "Die Verbindung zum MinIO-Server wurde erfolgreich hergestellt.")
        case .disconnected:
            showAlert(title: "Keine Verbindung", message: "Es konnte keine Verbindung zum MinIO-Server hergestellt werden. Bitte überprüfe deine Einstellungen.")
        case .error(let error):
            showAlert(title: "Verbindungsfehler", message: error.localizedDescription)
        }
    }
    
    private func showAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showingAlert = true
    }
}

struct MinIOStatusView_Previews: PreviewProvider {
    static var previews: some View {
        MinIOStatusView()
            .previewLayout(.sizeThatFits)
            .padding()
    }
} 