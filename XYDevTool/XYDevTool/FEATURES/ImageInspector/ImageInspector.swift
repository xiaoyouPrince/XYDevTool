//
//  ImageInspector.swift
//  XYDevTool
//
//  Created by will on 2025/4/8.
//  Copyright © 2025 XIAOYOU. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers
import ImageIO

import SDWebImage
import SDWebImageSwiftUI

struct ImageInfo: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let size: CGSize
    let format: String
    let frameCount: Int?
    let frameRate: Double?
    let duration: Double?

    static func == (lhs: ImageInfo, rhs: ImageInfo) -> Bool {
        return lhs.id == rhs.id || lhs.url == rhs.url
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct ImageInspector: View {
    @State private var images: [ImageInfo] = []
    @State private var selectedImage: ImageInfo?
    
    var body: some View {
        GeometryReader { geometry in
            HStack {
                List(images, selection: $selectedImage) {imageInfo in
                    HStack {
                        
                        AnimatedImage(url: imageInfo.url) {
                                    Circle().foregroundColor(.gray)
                                }
                        .resizable()
                        .scaledToFit()
                        .frame(width: 150, height: 150)
                        
                        Text(imageInfo.url.lastPathComponent)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(selectedImage == imageInfo ? Color.blue.opacity(0.3) : Color.clear)
                            .cornerRadius(5)
                            
                    }.onTapGesture {
                        selectedImage = imageInfo
                    }
                }
                .frame(minWidth: 200, maxWidth: 700)
                
                VStack(alignment: .leading, spacing: 10) {
                    if let selectedImage = selectedImage {
                        Text("Format: \(selectedImage.format)")
                        Text("Size: \(Int(selectedImage.size.width)) x \(Int(selectedImage.size.height))")
                        if let frameCount = selectedImage.frameCount {
                            Text("Frames: \(frameCount)")
                        }
                        if let frameRate = selectedImage.frameRate {
                            Text("Frame Rate: \(String(format: "%.2f", frameRate)) FPS")
                        }
                        if let duration = selectedImage.duration {
                            Text("Duration: \(String(format: "%.2f", duration)) sec")
                        }
                    } else {
                        Text("Select an image from the list")
                    }
                }
                .padding()
                .frame(maxWidth: geometry.size.width - 200)
            }
        }
        .onDrop(of: [UTType.image.identifier], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, _ in
                    if let url = item as? URL {
                        DispatchQueue.main.async {
                            if let imageInfo = extractImageInfo(from: url) {
                                // 在这里检查图像是否已经存在
                                if !images.contains(where: { $0.url == url }) {
                                    images.append(imageInfo)
                                    if selectedImage == nil {
                                        selectedImage = imageInfo
                                    }
                                } else {
                                    selectedImage = imageInfo
                                }
                            }
                        }
                    }
                }
            }
        }
        return true
    }

    
    private func extractImageInfo(from url: URL) -> ImageInfo? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        
        let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? CGFloat ?? 0
        let height = properties?[kCGImagePropertyPixelHeight] as? CGFloat ?? 0
        let format = url.pathExtension.uppercased()
        
        var frameCount: Int? = nil
        var frameRate: Double? = nil
        var duration: Double? = nil
        
        if format == "GIF" {
            frameCount = CGImageSourceGetCount(imageSource)
            if let gifProperties = properties?[kCGImagePropertyGIFDictionary] as? [CFString: Any] {
                duration = gifProperties[kCGImagePropertyGIFUnclampedDelayTime] as? Double
                if let frameCount = frameCount, let duration = duration {
                    frameRate = Double(frameCount) / duration
                }
            }
        }
        
        return ImageInfo(url: url, size: CGSize(width: width, height: height), format: format, frameCount: frameCount, frameRate: frameRate, duration: duration)
    }
}
