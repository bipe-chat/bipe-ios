//
// Copyright 2026 Proseio.
//
// SPDX-License-Identifier: AGPL-3.0-only
//

import CoreImage.CIFilterBuiltins
import SwiftUI

/// Profile links: `https://proseio.com.br/@handle`. The web page there falls back to the App Store;
/// the app opens it as a universal link (`applinks:proseio.com.br`).
public nonisolated enum ProseioProfileLink {
    public static let host = "proseio.com.br"

    public static func url(handle: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "/@\(handle)"
        return components.url
    }

    /// The handle in a profile link, lowercased, or `nil` when the URL is not one.
    public static func handle(from url: URL) -> String? {
        guard url.scheme == "https",
              url.host()?.lowercased() == host || url.host()?.lowercased() == "www.\(host)" else {
            return nil
        }
        let components = url.pathComponents.filter { $0 != "/" }
        guard components.count == 1, let first = components.first, first.hasPrefix("@") else { return nil }
        let handle = ProseioHandle.sanitize(first).lowercased()
        return ProseioHandle.localProblem(for: handle) == nil ? handle : nil
    }

    /// The Matrix user ID in a `https://matrix.to/#/@user:server` permalink.
    public static func matrixUserID(fromPermalink url: URL) -> String? {
        guard url.host() == "matrix.to", let fragment = url.fragment(percentEncoded: false) else { return nil }
        let path = fragment.split(separator: "?", maxSplits: 1).first.map(String.init) ?? fragment
        let userID = path.hasPrefix("/") ? String(path.dropFirst()) : path
        return userID.hasPrefix("@") && !userID.contains("/") ? userID : nil
    }
}

public extension ProseioHandleResolver {
    /// The profile link for a user with a known handle.
    func profileLink(for userID: String) -> URL? {
        handle(for: userID).flatMap(ProseioProfileLink.url(handle:))
    }

    /// Swaps a matrix.to user permalink for the Proseio profile link when the handle is known.
    func shareURL(for permalink: URL) -> URL {
        ProseioProfileLink.matrixUserID(fromPermalink: permalink).flatMap(profileLink(for:)) ?? permalink
    }
}

// MARK: - QR code

#if canImport(UIKit)

/// A QR code for a profile link, drawn with Core Image.
public struct ProseioQRCodeView: View {
    private let image: UIImage?

    public init(url: URL) {
        image = Self.makeImage(for: url.absoluteString)
    }

    public var body: some View {
        if let image {
            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .padding(16)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 16))
                .accessibilityHidden(true)
        }
    }

    private static func makeImage(for string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cgImage = CIContext().createCGImage(output, from: output.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}

/// Sheet content: the QR code of the user's own profile link, the handle and a share button.
public struct ProseioProfileQRCodeSheet: View {
    private let handle: String
    private let url: URL

    public init?(handle: String) {
        guard let url = ProseioProfileLink.url(handle: handle) else { return nil }
        self.handle = handle
        self.url = url
    }

    public var body: some View {
        VStack(spacing: 20) {
            Text(ProseioStrings.profileQrTitle)
                .font(.title3.bold())
            ProseioQRCodeView(url: url)
                .frame(maxWidth: 280)
            Text("@\(handle)")
                .font(.headline)
            Text(ProseioStrings.profileQrFooter)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            ShareLink(item: url) {
                Label(ProseioStrings.profileShare, systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
    }
}
#endif
