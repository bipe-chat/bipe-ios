//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

/// Makes a sticker from a photo, on the device (ADR 0029).
/// Vision cuts out the subject. Without a subject, the photo is cropped to a centred square.
public enum StickerMaker {
    /// WhatsApp's sticker size.
    public static let side = 512
    
    public static func sticker(fromImageData data: Data) -> StickerImportCandidate? {
        guard let image = orientedImage(from: data) else { return nil }
        let content = subjectCutout(of: image) ?? centredSquare(of: image)
        guard let content, let png = pngOnTransparentSquare(content) else { return nil }
        return StickerImporter.candidate(from: png)
    }
    
    // MARK: - Private
    
    /// Decodes the photo with its EXIF orientation applied, at most 2048 px on the long side.
    private static func orientedImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 2048
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
    
    private static func subjectCutout(of image: CGImage) -> CGImage? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image)
        do {
            try handler.perform([request])
            guard let result = request.results?.first, !result.allInstances.isEmpty else { return nil }
            let buffer = try result.generateMaskedImage(ofInstances: result.allInstances, from: handler, croppedToInstancesExtent: true)
            let ciImage = CIImage(cvPixelBuffer: buffer)
            return CIContext().createCGImage(ciImage, from: ciImage.extent)
        } catch {
            // The simulator and older devices may not run the request. The caller falls back to a square crop.
            return nil
        }
    }
    
    private static func centredSquare(of image: CGImage) -> CGImage? {
        let side = min(image.width, image.height)
        let rect = CGRect(x: (image.width - side) / 2, y: (image.height - side) / 2, width: side, height: side)
        return image.cropping(to: rect)
    }
    
    /// Draws `image` aspect-fit into a transparent `side` × `side` canvas and encodes it as PNG.
    private static func pngOnTransparentSquare(_ image: CGImage) -> Data? {
        guard let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        let scale = min(Double(side) / Double(image.width), Double(side) / Double(image.height))
        let width = Double(image.width) * scale
        let height = Double(image.height) * scale
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: (Double(side) - width) / 2, y: (Double(side) - height) / 2, width: width, height: height))
        guard let square = context.makeImage() else { return nil }
        
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, square, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }
}
