import SwiftUI
import CreateML
import AppKit

struct TrainingView: View {
    @State private var folderURL: URL?
    @State private var exportURL: URL?
    @State private var isTraining: Bool = false
    @State private var trainingProgress: Double = 0.0
    @State private var modelExported: Bool = false
    @State private var errorMessage: String = ""
    @State private var iterationCount: Int = 2000

    var body: some View {
        VStack {
            Text("Object Detection Model Trainer")
                .font(.title)
                .padding()

            Button(action: {
                selectFolder()
            }) {
                Text("Upload Folder")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }

            if let folderURL = folderURL {
                Text("Selected Folder: \(folderURL.lastPathComponent)")
                    .padding()
            }

            // Edit Iteration
            HStack {
                Text("Iterations:")
                Stepper(value: $iterationCount, in: 1000...10000) {
                    Text("\(iterationCount)")
                }
                .padding()
            }

            if isTraining {
                ProgressView(value: trainingProgress, total: 1.0)
                    .padding()
                    .progressViewStyle(LinearProgressViewStyle())
            }

            // Start training
            Button(action: {
                if let folderURL = folderURL {
                    selectExportLocation()
                }
            }) {
                Text("Start Training")
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(folderURL == nil || isTraining)

            if modelExported {
                Text("Model exported successfully!")
                    .padding()
                    .foregroundColor(.green)
            }

            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .padding()
                    .foregroundColor(.red)
            }
        }
        .padding()
    }

    // Select folder
    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Folder"
        
        if panel.runModal() == .OK {
            self.folderURL = panel.url
        }
    }

    // Export destination
    func selectExportLocation() {
        let savePanel = NSSavePanel()
        savePanel.prompt = "Choose Export Location"
        savePanel.nameFieldStringValue = "ObjectDetector.mlmodel"
        
        if savePanel.runModal() == .OK {
            self.exportURL = savePanel.url
            if let exportURL = exportURL, let folderURL = folderURL {
                trainObjectDetectionModel(with: folderURL, exportURL: exportURL)
            }
        }
    }

    // CreateML Model training
    func trainObjectDetectionModel(with folderURL: URL, exportURL: URL) {
        isTraining = true
        trainingProgress = 0.0
        errorMessage = ""

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                
                let dataSource = MLObjectDetector.DataSource.directoryWithImagesAndJsonAnnotation(at: folderURL)

               // parameter setting (maybe can add some more for higher accuracy)
                var parameters = MLObjectDetector.ModelParameters()
                parameters.maxIterations = iterationCount

                let model = try MLObjectDetector(trainingData: dataSource, parameters: parameters, annotationType: .boundingBox(units: .pixel, origin: .topLeft, anchor: .topLeft))


                try model.write(to: exportURL)

                DispatchQueue.main.async {
                    self.isTraining = false
                    self.modelExported = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.isTraining = false
                    self.errorMessage = "Training failed: \(error.localizedDescription)"
                    print("Training failed: \(error)")
                }
            }
        }
    }
}

