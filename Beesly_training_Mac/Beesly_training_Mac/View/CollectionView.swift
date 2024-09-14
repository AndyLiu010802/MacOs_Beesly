//
//  CollectionView.swift
//  MacOS
//
//  Created by Andy liu on 2024/8/16.
//

import SwiftUI
import Compression
import UniformTypeIdentifiers
import ZIPFoundation


struct CollectionView: View {
    @Binding var capturedVideos: [String: URL]
    @State private var selectedVideoNames: Set<String> = []
    @State private var isSelecting: Bool = false
    @State private var isShowingLabelChangeSheet = false
    @State private var newLabelName: String = ""

    var body: some View {
        VStack {
            HStack {
                Button(action: {
                    withAnimation {
                        isSelecting.toggle()
                        if !isSelecting {
                            selectedVideoNames.removeAll()
                        }
                    }
                }) {
                    Text(isSelecting ? "Cancel" : "Select")
                        .padding()
                        .foregroundColor(.white)
                        .background(isSelecting ? Color.red : Color.blue)
                        .cornerRadius(8)
                }

                Button(action: exportToZip) {
                    Text("Export to Zip")
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.green)
                        .cornerRadius(8)
                }
                .disabled(selectedVideoNames.isEmpty)

                Button(action: {
                    isShowingLabelChangeSheet = true
                }) {
                    Text("Change Label")
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.orange)
                        .cornerRadius(8)
                }
                .disabled(selectedVideoNames.isEmpty)

                Spacer()
            }

            List {
                ForEach(capturedVideos.keys.sorted(), id: \.self) { videoName in
                    VStack(alignment: .leading) {
                        HStack {
                            if isSelecting {
                                Image(systemName: selectedVideoNames.contains(videoName) ? "checkmark.circle.fill" : "circle")
                                    .onTapGesture {
                                        toggleSelection(for: videoName)
                                    }
                            }

                            Text(videoName)
                                .font(.headline)
                                .padding(.leading, isSelecting ? 0 : 20)
                        }
                    }
                }
            }
            .listStyle(PlainListStyle())
        }
        .padding()
        .sheet(isPresented: $isShowingLabelChangeSheet) {
            VStack {
                Text("Change Label")
                    .font(.headline)
                    .padding()

                TextField("New label", text: $newLabelName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()

                HStack {
                    Button("Cancel") {
                        isShowingLabelChangeSheet = false
                    }
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.gray)
                    .cornerRadius(8)

                    Spacer()

                    Button("Change") {
                        changeLabelName()
                        isShowingLabelChangeSheet = false
                    }
                    .padding()
                    .foregroundColor(.white)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                .padding()
            }
            .padding()
        }
    }

    private func toggleSelection(for videoName: String) {
        if selectedVideoNames.contains(videoName) {
            selectedVideoNames.remove(videoName)
        } else {
            selectedVideoNames.insert(videoName)
        }
    }

    private func exportToZip() {
        var jsonObjects: [[String: Any]] = []

        for videoName in selectedVideoNames {
            if let directory = capturedVideos[videoName] {
                let images = loadImages(from: directory)

                for imageURL in images {
                    if let capturedImage = loadCapturedImage(from: imageURL) {
                        let annotations = capturedImage.annotations.map { annotation in
                            return [
                                "label": annotation.label,
                                "coordinates": [
                                    "x": annotation.coordinates.x,
                                    "y": annotation.coordinates.y,
                                    "width": annotation.coordinates.width,
                                    "height": annotation.coordinates.height
                                ]
                            ]
                        }
                        jsonObjects.append([
                            "image": capturedImage.imageName,
                            "annotations": annotations
                        ])
                    }
                }
            }
        }

        do {
            let tempDirectory = FileManager.default.temporaryDirectory
            let uniqueFileName = "exported_annotations_\(UUID().uuidString).zip"
            let zipURL = tempDirectory.appendingPathComponent(uniqueFileName)

            let jsonURL = tempDirectory.appendingPathComponent("exported_annotations.json")
            let jsonData = try JSONSerialization.data(withJSONObject: jsonObjects, options: [.prettyPrinted])
            try jsonData.write(to: jsonURL)

            var filesToZip: [URL] = []

   
            filesToZip.append(jsonURL)

     
            for videoName in selectedVideoNames {
                if let directory = capturedVideos[videoName] {
                    let images = loadImages(from: directory)
                    for imageURL in images {
                        if imageURL.pathExtension.lowercased() != "json" {
                            filesToZip.append(imageURL)
                        }
                    }
                }
            }

       
            try createZipFile(at: zipURL, with: filesToZip)
            saveZipFile(zipURL: zipURL)
        } catch {
            print("Failed to create zip file: \(error.localizedDescription)")
        }
    }

    private func createZipFile(at zipURL: URL, with files: [URL]) throws {
        let archive = try Archive(url: zipURL, accessMode: .create)
        for fileURL in files {
           
            if fileURL.pathExtension.lowercased() == "json" && fileURL.lastPathComponent != "exported_annotations.json" {
                continue
            }
            try archive.addEntry(with: fileURL.lastPathComponent, relativeTo: fileURL.deletingLastPathComponent())
        }
    }






    private func saveZipFile(zipURL: URL) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType(filenameExtension: "zip")!]
        savePanel.nameFieldStringValue = "exported_annotations"

        if savePanel.runModal() == .OK, let destinationURL = savePanel.url {
            do {
                try FileManager.default.moveItem(at: zipURL, to: destinationURL)
                print("Zip file saved successfully at \(destinationURL.path)")
            } catch {
                print("Failed to save zip file: \(error.localizedDescription)")
            }
        }
    }


    private func changeLabelName() {
        for videoName in selectedVideoNames {
            if let directory = capturedVideos[videoName] {
                let images = loadImages(from: directory)

                for imageURL in images {
                    if var capturedImage = loadCapturedImage(from: imageURL) {
                        for i in 0..<capturedImage.annotations.count {
                            capturedImage.annotations[i].label = newLabelName
                        }
                        saveCapturedImage(capturedImage, to: imageURL)
                    }
                }
            }
        }
    }

    private func saveCapturedImage(_ capturedImage: CapturedImage, to imageURL: URL) {
        let jsonURL = imageURL.deletingPathExtension().appendingPathExtension("json")
        if let data = try? JSONEncoder().encode(capturedImage) {
            try? data.write(to: jsonURL)
        }
    }

    private func loadImages(from directory: URL) -> [URL] {
        let fileManager = FileManager.default
        return (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
    }

    private func loadCapturedImage(from imageURL: URL) -> CapturedImage? {
        let jsonURL = imageURL.deletingPathExtension().appendingPathExtension("json")
        if let data = try? Data(contentsOf: jsonURL),
           let capturedImage = try? JSONDecoder().decode(CapturedImage.self, from: data) {
            return capturedImage
        }
        return nil
    }
}
