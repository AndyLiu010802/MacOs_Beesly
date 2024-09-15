import SwiftUI
import AVFoundation

struct FrameSelectionView: View {
    let videoURL: URL
    var onSelectionComplete: (CGRect) -> Void
    
    @State private var image: NSImage?
    @State private var selectedRectangle: CGRect?
    @State private var isDraggingRectangle = false
    @State private var dragStartPoint: CGPoint?
    @State private var imageSize: CGSize = .zero
    
    var body: some View {
        VStack {
            if let image = image {
                GeometryReader { geometry in
                    ZStack {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .onAppear {
                                self.imageSize = geometry.size
                            }
                            .gesture(
                                TapGesture(count: 2)
                                    .onEnded {
                                        // Double-tap to clear the selection
                                        selectedRectangle = nil
                                    }
                            )
                        
                        // Draw selection rectangle
                        if let rect = selectedRectangle {
                            Rectangle()
                                .stroke(Color.red, lineWidth: 2)
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            if isDraggingRectangle {
                                                selectedRectangle?.origin.x += value.translation.width
                                                selectedRectangle?.origin.y += value.translation.height
                                            }
                                        }
                                        .onEnded { _ in
                                            isDraggingRectangle = false
                                        }
                                )
                                .onTapGesture {
                                    // Set flag to start moving the rectangle
                                    isDraggingRectangle = true
                                }
                        }
                    }
                    .contentShape(Rectangle()) // Make the entire area tappable
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if !isDraggingRectangle {
                                    if dragStartPoint == nil {
                                        dragStartPoint = value.location
                                    }
                                    let currentPoint = value.location
                                    let origin = CGPoint(
                                        x: min(dragStartPoint!.x, currentPoint.x),
                                        y: min(dragStartPoint!.y, currentPoint.y)
                                    )
                                    let size = CGSize(
                                        width: abs(currentPoint.x - dragStartPoint!.x),
                                        height: abs(currentPoint.y - dragStartPoint!.y)
                                    )
                                    selectedRectangle = CGRect(origin: origin, size: size)
                                }
                            }
                            .onEnded { _ in
                                dragStartPoint = nil
                            }
                    )
                }
                .aspectRatio(image.size, contentMode: .fit)
            } else {
                Text("Loading image...")
                    .onAppear(perform: loadFirstFrame)
            }
            HStack {
                Button("Cancel") {
                    // Dismiss the dialog without doing anything
                    onSelectionComplete(CGRect.zero)
                }
                .padding()
                Spacer()
                Button("Confirm") {
                    if let selectedRectangle = selectedRectangle {
                        // Convert selectedRectangle back to image coordinates
                        let scaleX = image!.size.width / imageSize.width
                        let scaleY = image!.size.height / imageSize.height
                        let rect = CGRect(
                            x: selectedRectangle.origin.x * scaleX,
                            y: selectedRectangle.origin.y * scaleY,
                            width: selectedRectangle.size.width * scaleX,
                            height: selectedRectangle.size.height * scaleY
                        )
                        onSelectionComplete(rect)
                    } else {
                        // No selection made
                        onSelectionComplete(CGRect.zero)
                    }
                }
                .padding()
                .disabled(selectedRectangle == nil)
            }
        }
        .padding()
        .frame(minWidth: 600, minHeight: 400)
    }
    
    private func loadFirstFrame() {
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        let time = CMTime(seconds: 0, preferredTimescale: 600)
        do {
            let imageRef = try generator.copyCGImage(at: time, actualTime: nil)
            self.image = NSImage(cgImage: imageRef, size: NSSize(width: imageRef.width, height: imageRef.height))
            self.imageSize = NSSize(width: imageRef.width, height: imageRef.height)
        } catch {
            print("Error generating first frame: \(error)")
        }
    }
}

