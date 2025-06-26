import SwiftUI
import PhotosUI

struct MediaSourceSelectionView: View {
    @Binding var isPresented: Bool
    @Binding var showingImagePicker: Bool
    @Binding var showingCamera: Bool
    @Binding var showingGPXImporter: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundColor(.blue)
                    
                    Text("Medien hinzufügen")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Wähle eine Quelle für deine Medien")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Media Source Options
                VStack(spacing: 16) {
                    // Galerie (Fotos & Videos)
                    MediaSourceButton(
                        icon: "photo.on.rectangle.angled",
                        title: "Galerie",
                        subtitle: "Fotos & Videos aus der Bibliothek",
                        color: .blue,
                        action: {
                            showingImagePicker = true
                            isPresented = false
                        }
                    )
                    
                    // Kamera
                    MediaSourceButton(
                        icon: "camera.fill",
                        title: "Kamera",
                        subtitle: "Foto oder Video aufnehmen",
                        color: .green,
                        action: {
                            showingCamera = true
                            isPresented = false
                        }
                    )
                    
                    // GPS-Track
                    MediaSourceButton(
                        icon: "location.fill.viewfinder",
                        title: "GPS-Track",
                        subtitle: "GPX-Datei importieren",
                        color: .orange,
                        action: {
                            showingGPXImporter = true
                            isPresented = false
                        }
                    )
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // Zusätzliche Info
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                        Text("Tipp:")
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Du kannst mehrere Medien gleichzeitig auswählen und später weitere hinzufügen.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Abbrechen") {
                        isPresented = false
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
}

struct MediaSourceButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                }
                
                // Text Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    MediaSourceSelectionView(
        isPresented: .constant(true),
        showingImagePicker: .constant(false),
        showingCamera: .constant(false),
        showingGPXImporter: .constant(false)
    )
} 