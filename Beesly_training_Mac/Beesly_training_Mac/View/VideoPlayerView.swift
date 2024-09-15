//
//  VideoPlayerView.swift
//  MacOS
//
//  Created by Andy Liu on 2024/8/12.
//

import SwiftUI
import AVKit
import Vision
import CoreImage


struct VideoPlayerView: View {
    @State private var player: AVPlayer? = nil
    @State private var videoURL: URL? = nil
    @State private var videoURLs: [URL] = []
    @State private var selectedVideos: Set<URL> = []
    @State private var searchText: String = ""
    @State private var isSelecting: Bool = false
    @State private var capturedFramesDirectory: URL? = nil
    @State private var showCaptureAlert: Bool = false
    @State private var showSelectionDialog: Bool = false
    @State private var templateRect: CGRect?
    @Binding var capturedVideos: [String: URL]
    
    var body: some View {
        VStack {
            if let player = player {
                VideoPlayer(player: player)
                    .aspectRatio(16/9, contentMode: .fit)
                    .cornerRadius(10)
                    .frame(width: 640, height: 360)
                    .padding()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 640, height: 360)
                    .cornerRadius(10)
                    .overlay(
                        Text("No video selected")
                            .foregroundColor(.gray)
                    )
                    .padding()
            }
            
            HStack {
                Button(action: uploadVideo) {
                    Label("Upload Video", systemImage: "folder")
                }
                .padding()
                
                Button(action: toggleSelectionMode) {
                    Label(isSelecting ? "Done" : "Select", systemImage: isSelecting ? "checkmark.circle" : "cursorarrow.click")
                }
                .padding()
                
                Button(action: deleteSelectedVideos) {
                    Label("Delete", systemImage: "trash")
                }
                .padding()
                .disabled(selectedVideos.isEmpty)
                
                Button(action: captureAction) {
                    Label("Capture", systemImage: "camera")
                }
                .padding()
                .disabled(selectedVideos.isEmpty)
                
                Spacer()
                
                TextField("Search videos...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
            }
            
            // Video List
            List(filteredVideos, id: \.self) { url in
                HStack {
                    if isSelecting {
                        Image(systemName: selectedVideos.contains(url) ? "checkmark.circle.fill" : "circle")
                            .onTapGesture {
                                toggleSelection(for: url)
                            }
                    }
                    
                    Text(url.lastPathComponent)
                        .onTapGesture {
                            if isSelecting {
                                toggleSelection(for: url)
                            } else {
                                playVideo(from: url)
                            }
                        }
                        .padding(.leading, isSelecting ? 10 : 0)
                }
            }
            .listStyle(PlainListStyle())
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
        .onAppear(perform: loadVideos)
        .alert(isPresented: $showCaptureAlert) {
            Alert(title: Text("Capture Completed"), message: Text("Captured frames from selected videos."), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $showSelectionDialog) {
            if let videoURL = videoURL {
                FrameSelectionView(videoURL: videoURL, onSelectionComplete: { rect in
                    if rect.isEmpty {
                        // User cancelled or didn't make a selection
                        self.showSelectionDialog = false
                    } else {
                        self.templateRect = rect
                        self.showSelectionDialog = false
                        self.performCapture()
                    }
                })
            }
        }
    }
    
    private var filteredVideos: [URL] {
        if searchText.isEmpty {
            return videoURLs
        } else {
            return videoURLs.filter { $0.lastPathComponent.lowercased().contains(searchText.lowercased()) }
        }
    }
    
    private func uploadVideo() {
        let panel = NSOpenPanel()
        panel.allowedFileTypes = ["mp4", "mov", "m4v"]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            if response == .OK, let url = panel.url {
                saveVideo(url)
                playVideo(from: url)
            }
        }
    }
    
    private func playVideo(from url: URL) {
        self.videoURL = url
        self.player = AVPlayer(url: url)
        self.player?.play()
        // Clear selection when new video is played
        self.templateRect = nil
    }
    
    private func saveVideo(_ url: URL) {
        videoURLs.append(url)
        saveToUserDefaults()
    }
    
    private func saveToUserDefaults() {
        let urls = videoURLs.map { $0.absoluteString }
        UserDefaults.standard.set(urls, forKey: "uploadedVideos")
    }
    
    private func loadVideos() {
        if let savedURLs = UserDefaults.standard.array(forKey: "uploadedVideos") as? [String] {
            videoURLs = savedURLs.compactMap { URL(string: $0) }
        }
    }
    
    private func toggleSelectionMode() {
        isSelecting.toggle()
        if !isSelecting {
            selectedVideos.removeAll()
        }
    }
    
    private func toggleSelection(for url: URL) {
        if selectedVideos.contains(url) {
            selectedVideos.remove(url)
        } else {
            selectedVideos.insert(url)
        }
    }
    
    private func deleteSelectedVideos() {
        if let currentVideoURL = videoURL, selectedVideos.contains(currentVideoURL) {
            player?.pause()
            player = nil
            videoURL = nil
        }
        
        videoURLs.removeAll { selectedVideos.contains($0) }
        selectedVideos.removeAll()
        saveToUserDefaults()
    }
    
    private func captureAction() {
        if videoURL != nil {
            showSelectionDialog = true
        } else {
            // Show an alert that no video is selected
            showCaptureAlert = true
        }
    }
    
    private func performCapture() {
        selectedVideos.forEach { url in
            capturedFramesDirectory = captureFrames(from: url, withTemplateRect: templateRect)
            if capturedFramesDirectory != nil {
                addToCollectionView(for: url)
            }
        }
        showCaptureAlert = true
    }
    
    private func addToCollectionView(for url: URL) {
        let videoName = url.lastPathComponent
        capturedVideos[videoName] = capturedFramesDirectory
    }
    
    private func captureFrames(from url: URL, withTemplateRect templateRect: CGRect?) -> URL? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Error creating directory: \(error)")
            return nil
        }
        
        if let templateRect = templateRect {
            // Object Tracking using Vision
            let duration = asset.duration
            let totalSeconds = Int(duration.seconds)
            
            var previousObservation: VNDetectedObjectObservation?
            let sequenceHandler = VNSequenceRequestHandler()
            
            for i in 0..<totalSeconds {
                let time = CMTime(seconds: Double(i), preferredTimescale: 600)
                do {
                    let imageRef = try generator.copyCGImage(at: time, actualTime: nil)
                    let imageWidth = CGFloat(imageRef.width)
                    let imageHeight = CGFloat(imageRef.height)
                    let ciImage = CIImage(cgImage: imageRef)
                    
                    let requestHandler = VNImageRequestHandler(cgImage: imageRef, options: [:])
                    
                    let request: VNTrackObjectRequest
                    
                    if i == 0 {
                        // Initialize observation with the templateRect
                        // Convert to Vision's normalized coordinate system (origin at bottom-left)
                        let normalizedRect = CGRect(
                            x: templateRect.origin.x / imageWidth,
                            y: (templateRect.origin.y) / imageHeight,
                            width: templateRect.size.width / imageWidth,
                            height: templateRect.size.height / imageHeight
                        )
                        let flippedRect = CGRect(
                            x: normalizedRect.origin.x,
                            y: 1 - normalizedRect.origin.y - normalizedRect.size.height,
                            width: normalizedRect.size.width,
                            height: normalizedRect.size.height
                        )
                        let initialObservation = VNDetectedObjectObservation(boundingBox: flippedRect)
                        request = VNTrackObjectRequest(detectedObjectObservation: initialObservation)
                        previousObservation = initialObservation
                    } else if let previousObservation = previousObservation {
                        request = VNTrackObjectRequest(detectedObjectObservation: previousObservation)
                    } else {
                        // If no previous observation is available, skip tracking
                        continue
                    }
                    
                    request.trackingLevel = .accurate
                    
                    do {
                        try requestHandler.perform([request])
                        if let result = request.results?.first as? VNDetectedObjectObservation {
                            previousObservation = result
                            
                            let bbox = result.boundingBox
                            let coordinates = boundingBoxToCoordinates(bbox, imageWidth: imageWidth, imageHeight: imageHeight)
                            
                            // Save the image and annotations
                            saveCapturedImage(
                                imageRef: imageRef,
                                frameIndex: i,
                                coordinates: coordinates,
                                directory: directory
                            )
                        } else {
                            print("No tracking results at time \(i)")
                            previousObservation = nil
                        }
                    } catch {
                        print("Tracking error at time \(i): \(error)")
                        previousObservation = nil
                    }
                    
                } catch {
                    print("Error generating image at time \(i): \(error)")
                }
            }
        } else {
            // Proceed as before, capturing frames without object tracking
            var times = [NSValue]()
            
            // Capturing one frame per second
            for i in stride(from: 0, to: asset.duration.seconds, by: 1) {
                let time = CMTime(seconds: i, preferredTimescale: 600)
                times.append(NSValue(time: time))
            }
            
            generator.generateCGImagesAsynchronously(forTimes: times) { requestedTime, image, actualTime, result, error in
                if let image = image, error == nil {
                    let frameFileName = "\(Int(actualTime.seconds)).jpg"
                    let frameURL = directory.appendingPathComponent(frameFileName)
                    let uiImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
                    if let data = uiImage.tiffRepresentation {
                        do {
                            // Save the image file
                            try data.write(to: frameURL)
                            
                            // Calculate default coordinates for the annotation
                            let imageSize = uiImage.size
                            
                            let rectWidth = Int(imageSize.width * 1/2)   // Half of the image width
                            let rectHeight = Int(imageSize.height * 1/2) // Half of the image height
                            
                            let x = Int((imageSize.width - CGFloat(rectWidth)) / 2)
                            let y = Int((imageSize.height - CGFloat(rectHeight)) / 2)
                            
                            let coordinates = CapturedImage.Coordinates(
                                x: x,
                                y: y,
                                width: rectWidth,
                                height: rectHeight
                            )
                            
                            // Create the CapturedImage structure
                            let capturedImage = CapturedImage(
                                imageName: frameFileName,
                                imageURL: frameURL,
                                annotations: [
                                    CapturedImage.Annotation(
                                        label: "",
                                        coordinates: coordinates
                                    )
                                ]
                            )
                            
                            // Convert CapturedImage to JSON Data
                            let jsonData = try JSONEncoder().encode(capturedImage)
                            
                            // Save JSON to a file
                            let jsonFileName = "\(Int(actualTime.seconds)).json"
                            let jsonURL = directory.appendingPathComponent(jsonFileName)
                            try jsonData.write(to: jsonURL)
                            
                        } catch {
                            print("Error saving image or JSON: \(error)")
                        }
                    }
                } else if let error = error {
                    print("Error generating image: \(error)")
                }
            }
        }
        
        return directory
    }
    
    private func boundingBoxToCoordinates(_ bbox: CGRect, imageWidth: CGFloat, imageHeight: CGFloat) -> CapturedImage.Coordinates {
        // Convert from Vision's normalized coordinates to your coordinate system (origin at top-left)
        let x = bbox.origin.x * imageWidth
        let y = bbox.origin.y * imageHeight
        let width = bbox.width * imageWidth
        let height = bbox.height * imageHeight
        
        let convertedY = y // Since Vision's y starts from bottom-left, and we want top-left, we keep y as is
        
        return CapturedImage.Coordinates(
            x: Int(x),
            y: Int(convertedY),
            width: Int(width),
            height: Int(height)
        )
    }
    
    private func saveCapturedImage(imageRef: CGImage, frameIndex: Int, coordinates: CapturedImage.Coordinates, directory: URL) {
        let frameFileName = "\(frameIndex).jpg"
        let frameURL = directory.appendingPathComponent(frameFileName)
        let uiImage = NSImage(cgImage: imageRef, size: NSSize(width: imageRef.width, height: imageRef.height))
        if let data = uiImage.tiffRepresentation {
            do {
                // Save the image file
                try data.write(to: frameURL)
                
                // Create the CapturedImage structure
                let capturedImage = CapturedImage(
                    imageName: frameFileName,
                    imageURL: frameURL,
                    annotations: [
                        CapturedImage.Annotation(
                            label: "",
                            coordinates: coordinates
                        )
                    ]
                )
                
                // Convert CapturedImage to JSON Data
                let jsonData = try JSONEncoder().encode(capturedImage)
                
                // Save JSON to a file
                let jsonFileName = "\(frameIndex).json"
                let jsonURL = directory.appendingPathComponent(jsonFileName)
                try jsonData.write(to: jsonURL)
                
            } catch {
                print("Error saving image or JSON: \(error)")
            }
        }
    }
}

