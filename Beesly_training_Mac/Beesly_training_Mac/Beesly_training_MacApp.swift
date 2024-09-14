//
//  MacOSApp.swift
//  MacOS
//
//  Created by Andy liu on 2024/8/11.
//

import SwiftUI

@main
struct YourApp: App {
    @State private var capturedVideos: [String: URL] = [:]

    var body: some Scene {
        WindowGroup {
            NavigationView {
                Sidebar(capturedVideos: $capturedVideos)
               
                Text("Select an option from the sidebar")
                    .frame(minWidth: 400, minHeight: 600)
            }
        }
    }
}

struct Sidebar: View {
    @State private var selectedView: String? = "VideoPlayer"
    @Binding var capturedVideos: [String: URL]
    
    var body: some View {
        List {
            NavigationLink(
                destination: VideoPlayerView(capturedVideos: $capturedVideos),
                tag: "VideoPlayer",
                selection: $selectedView
            ) {
                Label("Video Player", systemImage: "play.rectangle")
            }

            NavigationLink(
                destination: CollectionView(capturedVideos: $capturedVideos),
                tag: "Collection",
                selection: $selectedView
            ) {
                Label("Collection", systemImage: "photo.on.rectangle")
            }
            
            NavigationLink(
                destination: TrainingView(),
                tag: "Training",
                selection: $selectedView
            ) {
                Label("Training", systemImage: "gearshape")
            }


        }
        .listStyle(SidebarListStyle())
        .navigationTitle("Navigation")
    }
}

