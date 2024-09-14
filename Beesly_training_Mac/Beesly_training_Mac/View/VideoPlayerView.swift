//
//  VideoPlayerView.swift
//  MacOS
//
//  Created by Andy liu on 2024/8/12.
//

import SwiftUI
import AVKit

struct VideoPlayerView: View {
    @State private var player: AVPlayer? = nil
    @State private var videoURL: URL? = nil
    @State private var videoURLs: [URL] = []
    @State private var selectedVideos: Set<URL> = []
    @State private var searchText: String = ""
    @State private var isSelecting: Bool = false
    @State private var capturedFramesDirectory: URL? = nil
    @State private var showCaptureAlert: Bool = false
    @Binding var capturedVideos: [String: URL]
    
    var body: some View {
        VStack {
            if let player = player {
                VideoPlayer(player: player)
                    .aspectRatio(16/9, contentMode: .fit)
                    .cornerRadius(10)
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
        selectedVideos.forEach { url in
            capturedFramesDirectory = captureFrames(from: url)
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
    
    private func captureFrames(from url: URL) -> URL? {
        let asset = AVAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        var times = [NSValue]()
        
        // Capturing one frame per second
        for i in stride(from: 0, to: asset.duration.seconds, by: 1) {
            let time = CMTime(seconds: i, preferredTimescale: 600)
            times.append(NSValue(time: time))
        }

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Error creating directory: \(error)")
            return nil
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

                        // Define the width and height of your rectangle
                        let rectWidth = Int(imageSize.width * 1/2)   // Half of the image width
                        let rectHeight = Int(imageSize.height * 1/2) // Half of the image height

                        // Calculate the x and y to center the rectangle
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
        
        return directory
    }

}
