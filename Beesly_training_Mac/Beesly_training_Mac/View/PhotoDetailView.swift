//
//  PhotoDetailsView.swift
//  MacOS
//
//  Created by Andy liu on 2024/8/20.
//
import SwiftUI

struct PhotoDetailView: View {
    let image: NSImage
    let imageURL: URL
    @Binding var annotation: CapturedImage.Annotation
    @State private var label: String
    @State private var x: Int
    @State private var y: Int
    @State private var width: Int
    @State private var height: Int

    init(image: NSImage, imageURL: URL, annotation: Binding<CapturedImage.Annotation>) {
        self.image = image
        self.imageURL = imageURL
        self._annotation = annotation
      
        self._label = State(initialValue: annotation.wrappedValue.label)
        self._x = State(initialValue: annotation.wrappedValue.coordinates.x)
        self._y = State(initialValue: annotation.wrappedValue.coordinates.y)
        self._width = State(initialValue: annotation.wrappedValue.coordinates.width)
        self._height = State(initialValue: annotation.wrappedValue.coordinates.height)
    }

    var body: some View {
        VStack {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 300, maxHeight: 300)
                .padding()

            Text("Edit Annotation")
                .font(.headline)
                .padding(.top)

            Form {
                TextField("Label", text: $label)
                
                HStack {
                    Text("X: ")
                    TextField("X Coordinate", value: $x, formatter: NumberFormatter())
                }
                
                HStack {
                    Text("Y: ")
                    TextField("Y Coordinate", value: $y, formatter: NumberFormatter())
                }
                
                HStack {
                    Text("Width: ")
                    TextField("Width", value: $width, formatter: NumberFormatter())
                }
                
                HStack {
                    Text("Height: ")
                    TextField("Height", value: $height, formatter: NumberFormatter())
                }
            }
            .padding()

            Button(action: saveChanges) {
                Text("Save")
                    .padding()
            }

            Spacer()
        }
        .padding()
    }

    private func saveChanges() {
        annotation.label = label
        annotation.coordinates = CapturedImage.Coordinates(x: x, y: y, width: width, height: height)
        saveAnnotation()
    }

    private func saveAnnotation() {
        let capturedImage = CapturedImage(
            imageName: imageURL.lastPathComponent, imageURL: imageURL,
            annotations: [annotation]
        )
        
        let jsonURL = imageURL.deletingPathExtension().appendingPathExtension("json")
        
        do {
            let jsonData = try JSONEncoder().encode(capturedImage)
            try jsonData.write(to: jsonURL)
        } catch {
            print("Error saving annotation: \(error)")
        }
    }
}
