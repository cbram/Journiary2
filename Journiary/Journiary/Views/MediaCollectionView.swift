//
//  MediaCollectionView.swift
//  Journiary
//
//  Created by Christian Bram on 08.06.25.
//

import SwiftUI
import AVKit

struct MediaCollectionView: View {
    let mediaItems: [MediaItem]
    let onAddMedia: () -> Void
    let onDeleteMedia: (MediaItem) -> Void
    let onReorderMedia: ([MediaItem]) -> Void
    
    @State private var showingMediaViewer = false
    @State private var selectedMediaIndex = 0
    @State private var showingDeleteConfirmation = false
    @State private var mediaToDelete: MediaItem?
    @State private var reorderedMediaItems: [MediaItem] = []
    @State private var isEditMode = false
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Medien")
                    .font(.headline)
                
                Spacer()
                
                if !mediaItems.isEmpty {
                    Text("\(mediaItems.count) Element\(mediaItems.count == 1 ? "" : "e")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Edit/Done Button für Neuordnung
                if mediaItems.count > 1 {
                    Button(isEditMode ? "Fertig" : "Neuordnen") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if isEditMode {
                                // Speichere die neue Reihenfolge
                                onReorderMedia(reorderedMediaItems)
                            } else {
                                // Initialisiere reorderedMediaItems
                                reorderedMediaItems = mediaItems
                            }
                            isEditMode.toggle()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                Button(action: onAddMedia) {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            
            if mediaItems.isEmpty {
                // Leerer Zustand
                VStack(spacing: 16) {
                    Button(action: onAddMedia) {
                        VStack(spacing: 12) {
                            Image(systemName: "camera.badge.plus")
                                .font(.system(size: 40))
                                .foregroundColor(.blue)
                            
                            Text("Fotos oder Videos hinzufügen")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Tippen, um Kamera zu öffnen")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(30)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            } else {
                // Media Grid mit Drag-and-Drop
                if isEditMode {
                    // Edit-Modus: List mit Drag-and-Drop aktiviert
                    VStack(alignment: .leading, spacing: 12) {
                        List {
                            ForEach(reorderedMediaItems, id: \.objectID) { item in
                                HStack(spacing: 12) {
                                    // Thumbnail
                                    if let thumbnail = item.thumbnail {
                                        Image(uiImage: thumbnail)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 60, height: 60)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        Rectangle()
                                            .fill(Color(.systemGray4))
                                            .frame(width: 60, height: 60)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                Image(systemName: item.isVideo ? "video" : "photo")
                                                    .foregroundColor(.white)
                                            )
                                    }
                                    
                                    // Info
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.filename ?? "Unbenannt")
                                            .font(.headline)
                                            .lineLimit(1)
                                        
                                        Text(item.mediaTypeEnum?.displayName ?? "Medium")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        if let duration = item.formattedDuration {
                                            Text(duration)
                                                .font(.caption2)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    // Delete Button
                                    Button(action: {
                                        mediaToDelete = item
                                        showingDeleteConfirmation = true
                                    }) {
                                        Image(systemName: "minus.circle.fill")
                                            .foregroundColor(.red)
                                            .font(.title3)
                                    }
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if let index = reorderedMediaItems.firstIndex(of: item) {
                                        selectedMediaIndex = index
                                        showingMediaViewer = true
                                    }
                                }
                            }
                            .onMove(perform: moveItems)
                            .onDelete { indexSet in
                                for index in indexSet {
                                    let item = reorderedMediaItems[index]
                                    onDeleteMedia(item)
                                    reorderedMediaItems.remove(at: index)
                                }
                            }
                        }
                        .listStyle(PlainListStyle())
                        .frame(maxHeight: min(CGFloat(reorderedMediaItems.count * 80), 300))
                    }
                    
                    // Hinweis für Edit-Modus
                    Text("Ziehe die Medien mit dem ≡ Symbol, um sie neu zu ordnen")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                } else {
                    // Normaler Modus
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(Array(mediaItems.enumerated()), id: \.element.objectID) { index, item in
                            MediaThumbnailView(
                                mediaItem: item,
                                onTap: {
                                    selectedMediaIndex = index
                                    showingMediaViewer = true
                                },
                                onDelete: {
                                    mediaToDelete = item
                                    showingDeleteConfirmation = true
                                }
                            )
                        }
                        
                        // Add-Button
                        Button(action: onAddMedia) {
                            VStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                
                                Text("Hinzufügen")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .frame(maxWidth: .infinity, minHeight: 100)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                                    .blendMode(.overlay)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showingMediaViewer) {
            MediaViewerView(
                mediaItems: isEditMode ? reorderedMediaItems : mediaItems,
                selectedIndex: $selectedMediaIndex,
                onDismiss: {
                    showingMediaViewer = false
                }
            )
        }
        .alert("Medium löschen", isPresented: $showingDeleteConfirmation) {
            Button("Löschen", role: .destructive) {
                if let media = mediaToDelete {
                    onDeleteMedia(media)
                    // Entferne auch aus reorderedMediaItems wenn im Edit-Modus
                    if isEditMode, let index = reorderedMediaItems.firstIndex(of: media) {
                        reorderedMediaItems.remove(at: index)
                    }
                }
                mediaToDelete = nil
            }
            Button("Abbrechen", role: .cancel) {
                mediaToDelete = nil
            }
        } message: {
            Text("Möchtest du dieses Medium wirklich löschen?")
        }
        .onAppear {
            // Initialisiere reorderedMediaItems
            reorderedMediaItems = mediaItems
        }
        .onChange(of: mediaItems) {
            // Aktualisiere reorderedMediaItems wenn sich mediaItems ändern
            if !isEditMode {
                reorderedMediaItems = mediaItems
            }
        }
    }
    
    private func moveItems(from source: IndexSet, to destination: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            reorderedMediaItems.move(fromOffsets: source, toOffset: destination)
        }
    }
}

// MARK: - MediaThumbnailView

struct MediaThumbnailView: View {
    let mediaItem: MediaItem
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Thumbnail
                if let thumbnail = mediaItem.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(minHeight: 100)
                        .clipped()
                } else {
                    // Fallback für MediaItems ohne Thumbnail
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(minHeight: 100)
                        .overlay(
                            VStack {
                                Image(systemName: mediaItem.isVideo ? "video" : "photo")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                
                                Text(mediaItem.isVideo ? "Video" : "Foto")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        )
                }
                
                // Video-Indicator
                if mediaItem.isVideo {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            
                            VStack(spacing: 2) {
                                Image(systemName: "play.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)
                                
                                if let duration = mediaItem.formattedDuration {
                                    Text(duration)
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .shadow(radius: 2)
                                } else {
                                    Text("Video")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .shadow(radius: 2)
                                }
                            }
                            .padding(8)
                        }
                    }
                }
                
                // Delete-Button
                VStack {
                    HStack {
                        Spacer()
                        
                        Button(action: onDelete) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.red)
                                .background(Color.white, in: Circle())
                        }
                        .padding(4)
                    }
                    
                    Spacer()
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .cornerRadius(12)
        .clipped()
    }
}

// MARK: - MediaViewerView

struct MediaViewerView: View {
    let mediaItems: [MediaItem]
    @Binding var selectedIndex: Int
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $selectedIndex) {
                ForEach(Array(mediaItems.enumerated()), id: \.element.objectID) { index, item in
                    if item.isPhoto {
                        PhotoDetailView(mediaItem: item)
                            .tag(index)
                    } else {
                        VideoDetailView(mediaItem: item)
                            .tag(index)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            
            // Close Button
            VStack {
                HStack {
                    Button("Schließen") {
                        onDismiss()
                    }
                    .foregroundColor(.white)
                    .padding()
                    
                    Spacer()
                    
                    // Media Info
                    if selectedIndex < mediaItems.count {
                        let item = mediaItems[selectedIndex]
                        VStack(alignment: .trailing) {
                            Text("\(selectedIndex + 1) von \(mediaItems.count)")
                                .foregroundColor(.white)
                                .font(.caption)
                            
                            Text(item.mediaTypeEnum?.displayName ?? "Medium")
                                .foregroundColor(.white.opacity(0.7))
                                .font(.caption2)
                        }
                        .padding()
                    }
                }
                
                Spacer()
            }
        }
        .statusBarHidden(true)
        .gesture(
            DragGesture()
                .onChanged { _ in }
                .onEnded { gesture in
                    if abs(gesture.translation.height) > 100 {
                        onDismiss()
                    }
                }
        )
    }
}

// MARK: - PhotoDetailView

struct PhotoDetailView: View {
    let mediaItem: MediaItem
    
    var body: some View {
        ZStack {
            if let image = mediaItem.fullImage {
                AppleStyleZoomableImageView(image: image)
            } else {
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("Foto konnte nicht geladen werden")
                        .foregroundColor(.white.opacity(0.6))
                        .font(.headline)
                }
            }
        }
    }
}

// MARK: - VideoDetailView

struct VideoDetailView: View {
    let mediaItem: MediaItem
    @State private var isViewVisible = false
    
    var body: some View {
        ZStack {
            if let videoData = mediaItem.mediaData, isViewVisible {
                VideoPlayerView(videoData: videoData)
                    .onDisappear {
                        isViewVisible = false
                    }
            } else {
                VStack(spacing: 16) {
                    if let thumbnail = mediaItem.thumbnail {
                        // Zeige Thumbnail als Platzhalter
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .overlay(
                                Button(action: {
                                    isViewVisible = true
                                }) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 60))
                                        .foregroundColor(.white)
                                        .background(Color.black.opacity(0.6), in: Circle())
                                }
                            )
                    } else {
                        Image(systemName: "video.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.6))
                        
                        Text("Video konnte nicht geladen werden")
                            .foregroundColor(.white.opacity(0.6))
                            .font(.headline)
                        
                        VStack(spacing: 4) {
                            Text("Debug Info:")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.4))
                            Text("Dateiname: \(mediaItem.filename ?? "Unbekannt")")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.4))
                            Text("Dateigröße: \(mediaItem.formattedFileSize)")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.4))
                            Text("MediaType: \(mediaItem.mediaType ?? "Unbekannt")")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }
                }
            }
        }
        .onAppear {
            print("🎬 VideoDetailView für MediaItem angezeigt:")
            print("   Dateiname: \(mediaItem.filename ?? "Unbekannt")")
            print("   Dateigröße: \(mediaItem.filesize) bytes")
            print("   Hat Daten: \(mediaItem.mediaData != nil)")
            print("   MediaType: \(mediaItem.mediaType ?? "Unbekannt")")
            print("   Dauer: \(mediaItem.duration)s")
            
            // Verzögerte Aktivierung für bessere Performance
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if mediaItem.mediaData != nil {
                    isViewVisible = true
                }
            }
        }
        .onDisappear {
            isViewVisible = false
        }
    }
}

// MARK: - VideoPlayerView (Optimiert für Performance)

struct VideoPlayerView: UIViewControllerRepresentable {
    let videoData: Data
    @State private var isViewVisible = false
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        
        // Optimierte Player-Konfiguration für bessere Performance
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        controller.allowsPictureInPicturePlayback = false
        
        print("🎬 VideoPlayerView wird erstellt für \(videoData.count) bytes")
        
        // Setze Coordinator-Referenz
        context.coordinator.playerController = controller
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Automatisch aktivieren, wenn nicht bereits aktiviert
        if !isViewVisible {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isViewVisible = true
            }
        }
        
        // Player erstellen wenn View sichtbar ist
        if isViewVisible && uiViewController.player == nil {
            context.coordinator.setupPlayer(with: videoData, for: uiViewController)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        weak var playerController: AVPlayerViewController?
        weak var player: AVPlayer?
        private var playerItem: AVPlayerItem?
        private var timeObserver: Any?
        
        deinit {
            cleanupPlayer()
        }
        
        func setupPlayer(with videoData: Data, for controller: AVPlayerViewController) {
            // Cleanup existing player
            cleanupPlayer()
            
            // Erstelle temporäre Datei asynchron im Hintergrund
            Task.detached(priority: .userInitiated) {
                let tempURL = await self.createTemporaryVideoFile(from: videoData)
                
                await MainActor.run {
                    // Sichere Player-Erstellung
                    let asset = AVURLAsset(url: tempURL)
                    let playerItem = AVPlayerItem(asset: asset)
                    let player = AVPlayer(playerItem: playerItem)
                    
                    // Konfiguration für bessere Performance
                    player.automaticallyWaitsToMinimizeStalling = true
                    
                    self.player = player
                    self.playerItem = playerItem
                    controller.player = player
                    
                    // Status-Observer hinzufügen
                    self.setupPlayerObservers()
                    
                    print("✅ Player erfolgreich konfiguriert")
                }
            }
        }
        
        private func setupPlayerObservers() {
            guard let playerItem = playerItem else { return }
            
            // Status Observer
            playerItem.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
            
            // Playback Observer
            if let player = player {
                timeObserver = player.addPeriodicTimeObserver(
                    forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
                    queue: .main
                ) { time in
                    // Leichter Performance-Monitor
                    if CMTimeGetSeconds(time) > 0.1 {
                        // Player läuft erfolgreich
                    }
                }
            }
        }
        
        private func cleanupPlayer() {
            // Observer entfernen
            if let timeObserver = timeObserver, let player = player {
                player.removeTimeObserver(timeObserver)
                self.timeObserver = nil
            }
            
            playerItem?.removeObserver(self, forKeyPath: "status")
            
            // Player stoppen und freigeben
            player?.pause()
            player = nil
            playerItem = nil
        }
        
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            if keyPath == "status", let playerItem = object as? AVPlayerItem {
                switch playerItem.status {
                case .readyToPlay:
                    print("✅ Video bereit zur Wiedergabe")
                    // Automatisches Starten nur bei Bedarf
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                        if self?.player?.timeControlStatus != .playing {
                            self?.player?.play()
                            print("▶️ Video automatisch gestartet")
                        }
                    }
                case .failed:
                    print("❌ Video-Wiedergabe fehlgeschlagen: \(playerItem.error?.localizedDescription ?? "Unbekannter Fehler")")
                case .unknown:
                    print("❓ Video-Status unbekannt")
                @unknown default:
                    print("❓ Unbekannter Video-Status")
                }
            }
        }
        
        private func createTemporaryVideoFile(from data: Data) async -> URL {
            let tempDirectory = NSTemporaryDirectory()
            let fileName = "temp_video_\(UUID().uuidString).mov"
            let tempURL = URL(fileURLWithPath: tempDirectory).appendingPathComponent(fileName)
            
            do {
                try data.write(to: tempURL)
                print("✅ Temporäre Video-Datei erstellt: \(tempURL.lastPathComponent)")
                print("   Dateigröße: \(data.count) bytes")
            } catch {
                print("❌ Fehler beim Erstellen der temporären Video-Datei: \(error)")
            }
            
            return tempURL
        }
    }
}

// MARK: - Apple-Style Zoom/Pan Gesture Handler
struct ZoomPanGestureHandler: UIViewRepresentable {
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    @Binding var isZoomed: Bool
    let minScale: CGFloat
    let maxScale: CGFloat
    let containerSize: CGSize
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = true
        
        let pinchGesture = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handlePinch))
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handlePan))
        let doubleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleDoubleTap))
        
        doubleTapGesture.numberOfTapsRequired = 2
        
        pinchGesture.delegate = context.coordinator
        panGesture.delegate = context.coordinator
        doubleTapGesture.delegate = context.coordinator
        
        view.addGestureRecognizer(pinchGesture)
        view.addGestureRecognizer(panGesture)
        view.addGestureRecognizer(doubleTapGesture)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.containerSize = containerSize
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: ZoomPanGestureHandler
        var lastScale: CGFloat = 1.0
        var lastOffset: CGSize = .zero
        var containerSize: CGSize
        var isCurrentlyZooming: Bool = false
        var isCurrentlyPanning: Bool = false
        
        init(_ parent: ZoomPanGestureHandler) {
            self.parent = parent
            self.containerSize = parent.containerSize
        }
        
        // MARK: - Gesture Delegate - This is the key to Apple's behavior!
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Erlaubt simultane Zoom- und Pan-Gesten
            if gestureRecognizer is UIPinchGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer {
                return true
            }
            if gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIPinchGestureRecognizer {
                return true
            }
            
            // Blockiert TabView-Wischen nur wenn gezoomt oder aktiv zoomend/pannend
            if parent.scale > 1.01 || isCurrentlyZooming || isCurrentlyPanning {
                // Blockiert andere Gesten (TabView) nur wenn wir gezoomt sind
                return false
            }
            
            return true
        }
        
        // MARK: - Pinch Gesture
        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .began:
                lastScale = parent.scale
                isCurrentlyZooming = true
            case .changed:
                let newScale = min(max(lastScale * gesture.scale, parent.minScale), parent.maxScale)
                parent.scale = newScale
                parent.isZoomed = newScale > 1.01
            case .ended, .cancelled, .failed:
                isCurrentlyZooming = false
                // Snap back to 1.0 if close enough
                if parent.scale < 1.1 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        parent.scale = 1.0
                        parent.offset = .zero
                        parent.isZoomed = false
                    }
                }
            default:
                break
            }
        }
        
        // MARK: - Pan Gesture - Only when zoomed!
        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            // Nur pannen wenn gezoomt
            guard parent.scale > 1.01 else { return }
            
            switch gesture.state {
            case .began:
                lastOffset = parent.offset
                isCurrentlyPanning = true
            case .changed:
                let translation = gesture.translation(in: gesture.view)
                let maxOffsetX = max(0, (containerSize.width * parent.scale - containerSize.width) / 2)
                let maxOffsetY = max(0, (containerSize.height * parent.scale - containerSize.height) / 2)
                
                parent.offset = CGSize(
                    width: min(maxOffsetX, max(-maxOffsetX, lastOffset.width + translation.x)),
                    height: min(maxOffsetY, max(-maxOffsetY, lastOffset.height + translation.y))
                )
            case .ended, .cancelled, .failed:
                isCurrentlyPanning = false
            default:
                break
            }
        }
        
        // MARK: - Double Tap Gesture
        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if parent.scale > 1.01 {
                    // Zoom out
                    parent.scale = 1.0
                    parent.offset = .zero
                    parent.isZoomed = false
                } else {
                    // Zoom in
                    parent.scale = 2.5
                    parent.isZoomed = true
                    
                    // Center zoom on tap location
                    let location = gesture.location(in: gesture.view)
                    let viewCenter = CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
                    let offsetFromCenter = CGSize(
                        width: viewCenter.x - location.x,
                        height: viewCenter.y - location.y
                    )
                    parent.offset = offsetFromCenter
                }
            }
        }
    }
}

// MARK: - Apple-Style Zoomable Image View
struct AppleStyleZoomableImageView: View {
    let image: UIImage
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var isZoomed: Bool = false
    
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 6.0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: scale)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: offset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // UIKit Gesture Handler - This makes it work like Apple Photos!
                ZoomPanGestureHandler(
                    scale: $scale,
                    offset: $offset,
                    isZoomed: $isZoomed,
                    minScale: minScale,
                    maxScale: maxScale,
                    containerSize: geometry.size
                )
            }
        }
        .contentShape(Rectangle())
        .allowsHitTesting(true)
        // Key: Only block parent gestures when actually zoomed
        .simultaneousGesture(
            DragGesture(minimumDistance: 0).onChanged { _ in },
            including: isZoomed ? .all : .subviews
        )
    }
} 
