//
// Copyright 2026 Bipe.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

#if canImport(UIKit)
import ImageIO
import SwiftUI

/// Plays an animated image (animated WebP, APNG, GIF) with ImageIO. Kingfisher animates GIF only,
/// and WhatsApp stickers are animated WebP (bipe/docs/adr/0029-stickers-in-core.md).
public struct BipeAnimatedImage: UIViewRepresentable {
    private let data: Data
    
    public init(data: Data) {
        self.data = data
    }
    
    /// The number of frames in `data`. 1 for a still image, 0 when ImageIO cannot read it.
    public static func frameCount(of data: Data) -> Int {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return 0 }
        return CGImageSourceGetCount(source)
    }
    
    public func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        context.coordinator.start(data: data, in: view)
        return view
    }
    
    public func updateUIView(_ uiView: UIImageView, context: Context) {
        context.coordinator.start(data: data, in: uiView)
    }
    
    public static func dismantleUIView(_ uiView: UIImageView, coordinator: Coordinator) {
        coordinator.stop()
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    @MainActor
    public final class Coordinator {
        private var playingData: Data?
        private var generation = 0
        
        func start(data: Data, in view: UIImageView) {
            guard data != playingData else { return }
            stop()
            playingData = data
            let current = generation
            // The block runs on the main queue once per frame. Setting `stop` ends the animation.
            CGAnimateImageDataWithBlock(data as CFData, nil) { [weak self, weak view] _, image, stop in
                MainActor.assumeIsolated {
                    guard let self, let view, self.generation == current else {
                        stop.pointee = true
                        return
                    }
                    view.image = UIImage(cgImage: image)
                }
            }
        }
        
        func stop() {
            generation += 1
            playingData = nil
        }
    }
}
#endif
