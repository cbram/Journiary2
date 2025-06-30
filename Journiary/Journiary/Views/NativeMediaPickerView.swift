//
//  NativeMediaPickerView.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import SwiftUI
import UIKit
import Photos
import PhotosUI
import AVFoundation

// MARK: - Orientierungsfeste Wrapper-Klasse für UIImagePickerController

class OrientationFixedImagePickerController: UIViewController {
    let imagePicker = UIImagePickerController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Füge UIImagePickerController als Child hinzu
        addChild(imagePicker)
        view.addSubview(imagePicker.view)
        imagePicker.view.frame = view.bounds
        imagePicker.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imagePicker.didMove(toParent: self)
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        // Verwende die aktuelle Orientierung
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return windowScene.interfaceOrientation
        }
        return .portrait
    }
}

class OrientationFixedVideoPickerController: UIViewController {
    let imagePicker = UIImagePickerController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Füge UIImagePickerController als Child hinzu
        addChild(imagePicker)
        view.addSubview(imagePicker.view)
        imagePicker.view.frame = view.bounds
        imagePicker.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        imagePicker.didMove(toParent: self)
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        // Verwende die aktuelle Orientierung
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return windowScene.interfaceOrientation
        }
        return .portrait
    }
}

struct NativeMediaPickerView: View {
    @Environment(\.dismiss) private var dismiss
    
    let onMediaCaptured: (MediaItem) -> Void
    
    @State private var showingImagePicker = false
    @State private var selectedMediaType: MediaType = .photo
    @State private var showingActionSheet = false
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .camera
    @State private var hasSelectedMediaType = false
    @State private var orientation = UIDevice.current.orientation
    
    enum MediaType: String, CaseIterable {
        case photo = "Foto"
        case video = "Video"
        
        var iconName: String {
            switch self {
            case .photo: return "camera"
            case .video: return "video"
            }
        }
    }
    
    var body: some View {
        // NavigationView entfernt für bessere Querformat-Unterstützung
        VStack(spacing: isLandscape ? 15 : 30) {
            // Header mit Navigation
            HStack {
                Button("Abbrechen") {
                    dismiss()
                }
                .foregroundColor(.blue)
                
                Spacer()
                
                Text("Medien")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Placeholder für symmetrisches Layout
                Button("Abbrechen") {
                    dismiss()
                }
                .opacity(0)
                .disabled(true)
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            if !isLandscape {
                Spacer()
                
                // App Icon/Logo - nur im Portrait
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                VStack(spacing: 16) {
                    Text("Medien aufnehmen")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Wählen Sie aus, ob Sie ein Foto oder Video aufnehmen möchten. Die native iPhone Kamera-App wird geöffnet.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
            } else {
                // Kompaktes Header für Querformat
                VStack(spacing: 8) {
                    Text("Medien aufnehmen")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Wählen Sie aus, ob Sie ein Foto oder Video aufnehmen möchten.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)
            }
            
            // Media Type Selection - angepasst für Orientierung
            if isLandscape {
                // Horizontal layout für Querformat
                HStack(spacing: 20) {
                    // Photo Button
                    Button(action: {
                        selectedMediaType = .photo
                        hasSelectedMediaType = true
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            checkCameraPermissionAndOpen()
                        }
                    }) {
                        HStack {
                            Image(systemName: "camera")
                                .font(.title2)
                            Text("Foto aufnehmen")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    // Video Button
                    Button(action: {
                        selectedMediaType = .video
                        hasSelectedMediaType = true
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            checkCameraPermissionAndOpen()
                        }
                    }) {
                        HStack {
                            Image(systemName: "video")
                                .font(.title2)
                            Text("Video aufnehmen")
                                .font(.headline)
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
            } else {
                // Vertikales Layout für Portrait
                VStack(spacing: 20) {
                    // Photo Button
                    Button(action: {
                        selectedMediaType = .photo
                        hasSelectedMediaType = true
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            checkCameraPermissionAndOpen()
                        }
                    }) {
                        HStack {
                            Image(systemName: "camera")
                                .font(.title2)
                            Text("Foto aufnehmen")
                                .font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    // Video Button
                    Button(action: {
                        selectedMediaType = .video
                        hasSelectedMediaType = true
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            checkCameraPermissionAndOpen()
                        }
                    }) {
                        HStack {
                            Image(systemName: "video")
                                .font(.title2)
                            Text("Video aufnehmen")
                                .font(.headline)
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
            }
            
            if !isLandscape {
                Spacer()
            }
        }
        .background(Color(.systemBackground))
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                orientation = UIDevice.current.orientation
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            if selectedMediaType == .photo {
                PhotoPickerView(
                    onImagePicked: handleImagePicked,
                    onCancel: {
                        showingImagePicker = false
                    }
                )
                .ignoresSafeArea() // Wichtig für korrekte Orientierung
                .statusBarHidden(true) // Bessere Vollbild-Darstellung
            } else {
                VideoPickerView(
                    onVideoPicked: handleVideoPicked,
                    onCancel: {
                        showingImagePicker = false
                    }
                )
                .ignoresSafeArea() // Wichtig für korrekte Orientierung
                .statusBarHidden(true) // Bessere Vollbild-Darstellung
            }
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text("Kamera nicht verfügbar"),
                message: Text("Die Kamera ist auf diesem Gerät nicht verfügbar."),
                buttons: [.default(Text("OK"))]
            )
        }
    }
    
    // Computed property für Orientierungserkennung
    private var isLandscape: Bool {
        // Verwende mehrere Methoden für zuverlässige Orientierungserkennung
        let screenBounds = UIScreen.main.bounds
        let deviceOrientation = UIDevice.current.orientation
        let interfaceOrientation = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.interfaceOrientation
        
        // Prüfe verschiedene Orientierungsquellen
        let screenIsWider = screenBounds.width > screenBounds.height
        let deviceIsLandscape = deviceOrientation.isLandscape
        let interfaceIsLandscape = interfaceOrientation?.isLandscape ?? false
        
        // Wenn eine der Quellen Querformat anzeigt, verwende Querformat-Layout
        return screenIsWider || deviceIsLandscape || interfaceIsLandscape
    }
    
    // MARK: - Private Methods
    
    private func resetState() {
        // Reset State für saubere Kamera-Auswahl
        // NICHT selectedMediaType zurücksetzen - nur UI-States
        hasSelectedMediaType = false
        showingImagePicker = false
        showingActionSheet = false
        imagePickerSourceType = .camera
        
        print("🔄 NativeMediaPickerView State zurückgesetzt (MediaType bleibt: \(selectedMediaType.rawValue))")
    }
    
    private func checkCameraPermissionAndOpen() {
        // Überprüfe Kamera-Verfügbarkeit
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showingActionSheet = true
            return
        }
        
        // Überprüfe Kamera-Berechtigung
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch authStatus {
        case .authorized:
            openCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        openCamera()
                    } else {
                        // Berechtigung verweigert
                        showingActionSheet = true
                    }
                }
            }
        case .denied, .restricted:
            // Berechtigung bereits verweigert
            showingActionSheet = true
        @unknown default:
            showingActionSheet = true
        }
    }
    
    private func openCamera() {
        imagePickerSourceType = .camera
        showingImagePicker = true
    }
    
    private func handleImagePicked(_ image: UIImage) {
        // Haptic Feedback für erfolgreiche Aufnahme
        provideSafeHapticFeedback(.success)
        
        // Speichere Bild in der Galerie
        saveImageToPhotoLibrary(image)
        
        // Erstelle MediaItem für die App
        let context = EnhancedPersistenceController.shared.container.viewContext
        if let mediaItem = MediaItem.createPhoto(from: image, in: context) {
            onMediaCaptured(mediaItem)
            print("📷 Neues Foto hinzugefügt (Native Kamera)")
            print("   Dateigröße: \(mediaItem.filesize / 1024)KB")
        }
        
        showingImagePicker = false
        // resetState() entfernt - kann MediaType beeinflussen
        dismiss()
    }
    
    private func handleVideoPicked(_ videoURL: URL) {
        // Haptic Feedback für erfolgreiche Aufnahme
        provideSafeHapticFeedback(.success)
        
        // Speichere Video in der Galerie
        saveVideoToPhotoLibrary(videoURL)
        
        // Erstelle MediaItem für die App - ASYNCHRON im Hintergrund
        Task.detached(priority: .userInitiated) {
            do {
                let videoData = try Data(contentsOf: videoURL)
                
                await MainActor.run {
                    let context = EnhancedPersistenceController.shared.container.viewContext
                    if let mediaItem = MediaItem.createVideoAsync(from: videoData, in: context) {
                        onMediaCaptured(mediaItem)
                        print("📷 Neues Video hinzugefügt (Native Kamera)")
                        print("   Dateigröße: \(videoData.count / 1024)KB")
                    }
                    
                    showingImagePicker = false
                    // resetState() entfernt - kann MediaType beeinflussen
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    print("Fehler beim Laden der Video-Daten: \(error)")
                    showingImagePicker = false
                    // resetState() entfernt - kann MediaType beeinflussen
                    dismiss()
                }
            }
        }
    }
    
    private func saveImageToPhotoLibrary(_ image: UIImage) {
        // Moderne Photos-Berechtigung verwenden
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        let saveImage = {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            print("✅ Foto erfolgreich in der Galerie gespeichert")
        }
        
        switch authStatus {
        case .authorized, .limited:
            saveImage()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                DispatchQueue.main.async {
                    if status == .authorized || status == .limited {
                        saveImage()
                    } else {
                        print("⚠️ Berechtigung für Galerie-Zugriff verweigert")
                    }
                }
            }
        case .denied, .restricted:
            print("⚠️ Galerie-Berechtigung ist eingeschränkt oder verweigert")
        @unknown default:
            print("⚠️ Unbekannter Galerie-Berechtigungsstatus")
        }
    }
    
    private func saveVideoToPhotoLibrary(_ videoURL: URL) {
        // Moderne Photos-Berechtigung verwenden
        let authStatus = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        let saveVideo = {
            PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            }) { success, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Fehler beim Speichern des Videos: \(error.localizedDescription)")
                    } else if success {
                        print("✅ Video erfolgreich in der Galerie gespeichert")
                    }
                }
            }
        }
        
        switch authStatus {
        case .authorized, .limited:
            saveVideo()
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                if status == .authorized || status == .limited {
                    saveVideo()
                } else {
                    print("⚠️ Berechtigung für Galerie-Zugriff verweigert")
                }
            }
        case .denied, .restricted:
            print("⚠️ Galerie-Berechtigung ist eingeschränkt oder verweigert")
        @unknown default:
            print("⚠️ Unbekannter Galerie-Berechtigungsstatus")
        }
    }
    
    // MARK: - Sichere Haptic Feedback-Implementierung
    
    private func provideSafeHapticFeedback(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        // Prüfe ob Haptic Engine verfügbar ist
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        
        // Verwende einen neuen Generator für jede Feedback-Instanz
        // Das verhindert "Haptic Engine does not exist" Fehler
        DispatchQueue.main.async {
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            
            // Kurze Verzögerung, um sicherzustellen, dass der Generator bereit ist
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                generator.notificationOccurred(type)
            }
        }
    }
}

// MARK: - Separate Picker Views

struct PhotoPickerView: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    let onCancel: () -> Void
    
    func makeUIViewController(context: Context) -> OrientationFixedImagePickerController {
        let pickerController = OrientationFixedImagePickerController()
        let picker = pickerController.imagePicker
        
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        picker.mediaTypes = ["public.image"]
        picker.cameraCaptureMode = .photo
        
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.cameraDevice = .rear
        }
        
        return pickerController
    }
    
    func updateUIViewController(_ uiViewController: OrientationFixedImagePickerController, context: Context) {
        // Keine Änderungen erforderlich - OrientationFixedImagePickerController verwaltet die Orientierung
    }
    
    func makeCoordinator() -> PhotoCoordinator {
        PhotoCoordinator(self)
    }
    
    class PhotoCoordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PhotoPickerView
        
        init(_ parent: PhotoPickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
        
        // Wichtig: Lass UIImagePickerController seine eigene Orientierung verwalten
        func navigationControllerSupportedInterfaceOrientations(_ navigationController: UINavigationController) -> UIInterfaceOrientationMask {
            return .all
        }
        
        func navigationControllerPreferredInterfaceOrientationForPresentation(_ navigationController: UINavigationController) -> UIInterfaceOrientation {
            // Lass den UIImagePickerController entscheiden
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.interfaceOrientation ?? .portrait
        }
    }
}

struct VideoPickerView: UIViewControllerRepresentable {
    let onVideoPicked: (URL) -> Void
    let onCancel: () -> Void
    
    func makeUIViewController(context: Context) -> OrientationFixedVideoPickerController {
        let pickerController = OrientationFixedVideoPickerController()
        let picker = pickerController.imagePicker
        
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        picker.mediaTypes = ["public.movie"]
        picker.cameraCaptureMode = .video
        picker.videoMaximumDuration = 300
        picker.videoQuality = .typeHigh
        
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.cameraDevice = .rear
        }
        
        return pickerController
    }
    
    func updateUIViewController(_ uiViewController: OrientationFixedVideoPickerController, context: Context) {
        // Keine Änderungen erforderlich - OrientationFixedVideoPickerController verwaltet die Orientierung
    }
    
    func makeCoordinator() -> VideoCoordinator {
        VideoCoordinator(self)
    }
    
    class VideoCoordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: VideoPickerView
        
        init(_ parent: VideoPickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let videoURL = info[.mediaURL] as? URL {
                parent.onVideoPicked(videoURL)
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
        
        // Wichtig: Lass UIImagePickerController seine eigene Orientierung verwalten
        func navigationControllerSupportedInterfaceOrientations(_ navigationController: UINavigationController) -> UIInterfaceOrientationMask {
            return .all
        }
        
        func navigationControllerPreferredInterfaceOrientationForPresentation(_ navigationController: UINavigationController) -> UIInterfaceOrientation {
            // Lass den UIImagePickerController entscheiden
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?.interfaceOrientation ?? .portrait
        }
    }
}

// MARK: - Legacy ImagePickerView (not used anymore)

struct ImagePickerView: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let mediaType: NativeMediaPickerView.MediaType
    let onImagePicked: (UIImage) -> Void
    let onVideoPicked: (URL) -> Void
    let onCancel: () -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        print("🔧 ImagePickerView.makeUIViewController aufgerufen")
        print("🔧 Empfangener MediaType: \(mediaType.rawValue)")
        
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        
        // Ultra-sichere Kamera-Konfiguration (verhindert alle Hardware-Konflikte)
        if sourceType == .camera {
            // Prüfe verfügbare Kamera-Geräte vor Konfiguration
            let availableDeviceTypes = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.builtInWideAngleCamera, .builtInTelephotoCamera, .builtInUltraWideCamera],
                mediaType: .video,
                position: .unspecified
            ).devices
            
            print("📷 Verfügbare Kamera-Geräte: \(availableDeviceTypes.count)")
            
            // Verwende nur die sichersten Grundeinstellungen
            print("🎯 Konfiguriere für MediaType: \(mediaType.rawValue)")
            switch mediaType {
            case .photo:
                picker.mediaTypes = ["public.image"]
                picker.cameraCaptureMode = .photo
                
                // Nur Standard-Rückkamera verwenden (sicherste Option)
                if availableDeviceTypes.contains(where: { $0.position == .back }) {
                    picker.cameraDevice = .rear
                } else {
                    picker.cameraDevice = .front  // Fallback für Geräte ohne Rückkamera
                }
                
                // KEIN Flash-Mode setzen - überlasse alles der nativen App
                
            case .video:
                picker.mediaTypes = ["public.movie"]
                picker.cameraCaptureMode = .video
                
                // Adaptive Qualität basierend auf verfügbarer Hardware
                if availableDeviceTypes.count > 1 {
                    // Moderne iPhones mit mehreren Kameras
                    picker.videoQuality = .typeHigh
                } else {
                    // Ältere iPhones oder iPads
                    picker.videoQuality = .typeMedium
                }
                
                // Konservative maximale Dauer
                picker.videoMaximumDuration = 300  // 5 Minuten
                
                // Sichere Kamera-Auswahl
                if availableDeviceTypes.contains(where: { $0.position == .back }) {
                    picker.cameraDevice = .rear
                } else {
                    picker.cameraDevice = .front
                }
            }
            
            // KEINE erweiterten Kamera-Modi setzen
            // KEINE Overlay-Views hinzufügen
            // KEINE benutzerdefinierten Kontrollen
            // Überlasse alles der nativen iPhone Kamera-App
            
            print("✅ Sichere Kamera-Konfiguration abgeschlossen")
            print("   MediaType: \(mediaType.rawValue)")
            print("   MediaTypes: \(picker.mediaTypes)")
            print("   CameraCaptureMode: \(picker.cameraCaptureMode.rawValue)")
            print("   Kamera-Position: \(picker.cameraDevice == .rear ? "Hinten" : "Vorne")")
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            
            if let image = info[.originalImage] as? UIImage {
                parent.onImagePicked(image)
            } else if let videoURL = info[.mediaURL] as? URL {
                parent.onVideoPicked(videoURL)
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}

// MARK: - Preview

struct NativeMediaPickerView_Previews: PreviewProvider {
    static var previews: some View {
        NativeMediaPickerView { _ in
            // Preview callback
        }
    }
} 