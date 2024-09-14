//
//  AnnotatedImages.swift
//  MacOS
//
//  Created by Andy liu on 2024/8/20.
//
import Foundation

struct CapturedImage: Codable {
    let imageName: String
    let imageURL: URL 
    var annotations: [Annotation]
    
    struct Annotation: Codable {
        var label: String
        var coordinates: Coordinates
    }
    
    struct Coordinates: Codable {
        var x: Int
        var y: Int
        var width: Int
        var height: Int
    }
}
